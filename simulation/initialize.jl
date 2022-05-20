"""
This file contains all the functions that have to initialize the system.
For example, loading the network, the block characteristics, the timetables
"""



# function loadOPoints!(file::String, RN::Network)
#
#     file  = Opt["opoint_file"]
#     df = DataFrame(CSV.File(file, comment="#"))
#
#     for i = 1:nrow(df)
#         name = string(df.id[i])
#         op = OPoint(
#                 name,
#                 i,
#                 df.lat[i],
#                 df.long[i],
#                 String[],
#                 String[],
#                 false
#         )
#         RN.n += 1
#         RN.nodes[name]=op
#     end
#     df = nothing # explicitly free the memory
# end


function loadInfrastructure()::Network
    """
    takes the blocks.csv file and builds the network
    """
    #creating and initializing a data struct network
    RN = Network()

    fileblock = Opt["block_file"]
    df = DataFrame(CSV.File(fileblock, comment="#"))

    for i = 1:nrow(df)
        name = df.id[i]; ntracks = df.tracks[i];
        RN.blocks[name] = initBlock(name, ntracks);
        RN.nb += 1
    end

    df = nothing # explicitly free the memory

    # insert the empty block
    RN.blocks[""] = Block();

    Opt["print_flow"] && println("Infrastructure loaded")
    RN
end

"""takes the timetable.csv file and loads the Fleet """
function loadFleet()::Fleet

    file = Opt["timetable_file"];
    trains_info_file=Opt["trains_info_file"];
    rotation_file = Opt["rotation_file"];

    Opt["print_flow"] && println("Loading fleet information")

    FL = Fleet(0,Dict{String, Train}())
    df = DataFrame(CSV.File(file, comment="#"))

    df.duetime = dateToSeconds.(df.duetime)

    Trains = FL.train;

    #take direction from the file
    train2dir = Dict{String,Int}();
    if isfile(trains_info_file)
        train2dir = CSV.File(trains_info_file) |> Dict
    elseif Opt["multi_stations"]
        println("multi platforms activated but no file found. Add file and restart")
        exit()
    end

    Rot = Dict{String,String}();
    if isfile(rotation_file)
        Rot = Dict(CSV.File(rotation_file));
        Opt["print_flow"] && println("Rotations loaded")
    end

    #right now the train track is only n.5
    track=5

    # build the schedule for every train
    for i = 1:nrow(df)
        (train, bts, kind, duetime) = df[i,:];

        #restore original name from poppers since the direction is associated with the plain name
        unpopped  = replace(train, r"_pop.*" => "");
        direction = get(train2dir, unpopped, 0);

        str = Transit(
                train,
                bts,
                kind,
                duetime
        )

        if !haskey(Trains, train)
            Trains[train] = Train(
                                train,
                                track,direction,
                                get(Rot, unpopped, ""),
                                Transit[],
                                DynTrain(0,"",""),
                                Dict{String,Int}()
                            );
        end
        push!(Trains[train].schedule, str);
    end

    FL.n = length(Trains);
    df = nothing; # free memory for a better world

    # initialize the delay on the blocks
    for train in keys(Trains)
        # be sure the schedule is sorted
        Schedule = Trains[train].schedule;
        issorted(Schedule) || sort!(Schedule)

        # for i = 1:length(Schedule)-1
        #     bts = Schedule[i].opid;
        #     nextbts = Schedule[i+1].opid;
        #     block = bts*"-"*nextbts;
        #
        #     Trains[train].delay[block] = 0
        # end

    end

    Opt["print_flow"] && println("Fleet loaded ($(FL.n) trains)")
    return FL

end


#customized sorting, for correctly sorting strings based on last digits
# function custom_cmp(x::String)
#     arr_str = rsplit(x, "_",limit=2)
#     str1, _ = arr_str[1], arr_str[2]
#     number_idx = findlast(isdigit, arr_str[2])
#     num,str2 = SubString(arr_str[2], 1, number_idx), SubString(arr_str[2], number_idx+1, length(arr_str[2]))
#     return str1,parse(Int, num)
# end

"""
Takes all the delay files in the data/delays/ directory
and loads it in a vector of dataframes;
each df defines a different simulation to be done
"""
function loadDelays()::Vector{DataFrame}

    print_imposed_delay = Opt["print_imposed_delay"];

    delays_array=DataFrame[];

    repo = Opt["imposed_delay_repo_path"]
    occursin(r"/$", repo) || (repo *= "/"); # add slash to the folder name if not present

    files=sort!(read_non_hidden_files(repo))


    if isempty(files)
        print_imposed_delay && println("No imposed delay file was found. Simulating without imposed delays.")
        return (delays_array,1);
    end

    if Opt["multi_simulation"]
        for file in files
            delay= DataFrame(CSV.File(repo*file, comment="#"))
            push!(delays_array,delay)
        end
    else
        file = files[1];
        delay= DataFrame(CSV.File(repo*file, comment="#"))
        push!(delays_array,delay)
    end

    Opt["print_flow"] && println("Delays loaded. The number of delay scenarios is: ",length(delays_array));
    delay=nothing

    return delays_array
end

"""
takes the vector of df,
resets to 0 the delays imposed to the previews simulation
"""
function resetDelays(FL::Fleet, df::DataFrame)
    print_imposed_delay = Opt["print_imposed_delay"];

    for i = 1:nrow(df)
        (train, block, delay) = df[i,:];

        # FL.train[train].delay[block]=0
        FL.train[train].delay = Dict{String,Int}();
        if print_imposed_delay
            println("Reset $delay to train $train, at block $block.")
        end
    end

    Opt["print_flow"] && println("$(nrow(df)) Delays reset");
    df = nothing;

end

function resetDelays(FL::Fleet)
    print_imposed_delay = Opt["print_imposed_delay"];

    for Train in values(FL.train)
        Train.delay = Dict{String,Int}();
    end

    Opt["print_flow"] && println("Delays reset");

end

"""imposes the delays for the actual simulation """
function imposeDelays(FL::Fleet, df::DataFrame)

    print_imposed_delay = Opt["print_imposed_delay"];

    # reset the delays imposed in the previous simulation
    resetDelays(FL);

    # df = delays_array[simulation_id];

    c=0;
    for i = 1:nrow(df)
        (train, block, delay) = df[i,:];

        FL.train[train].delay[block]=delay

        if print_imposed_delay
            println("Imposed $delay to train $train, at block $block.")
        end
    end

    Opt["print_flow"] && println("$(nrow(df)) Delays imposed");
    df = nothing;

end

"""
Initializes the Event dict, having times as keys and the first train event in that time as values
"""
function initEvent(FL::Fleet)::Dict{Int,Vector{Transit}}

    E = Dict{Int,Vector{Transit}}()

    Opt["print_flow"] && println("Initializing the event table")

    for trainid in keys(FL.train)

        Opt["print_train_list"] && println("\tTrain $trainid")

        # the transits of a train were sorted in LoadFleet()
        s = FL.train[trainid].schedule[1]; # first transit
        duetime = s.duetime;

        get!(E, duetime, Transit[]);
        push!(E[duetime], s)

    end

    E
end
