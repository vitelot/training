# This file contains all the functions that have to initialize the system.
# For example, loading the network, the block characteristics, the timetables

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


"""
takes the blocks.csv and stations.csv files and builds the network
"""
function loadInfrastructure()::Network
    #creating and initializing a data struct network
    RN = Network();

    blockfile = Opt["block_file"];
    stationfile = Opt["station_file"];

    df = DataFrame(CSV.File(blockfile, comment="#"));
    initBlocks(df, RN);

    df = DataFrame(CSV.File(stationfile, comment="#"));
    initStations(df, RN);

    #df = nothing # explicitly free the memory

    # insert the empty block
    RN.blocks[""] = Block();
    RN.stations[""] = Station();
    RN.superblocks[0] = SuperBlock(0);

    Opt["print_flow"] && @info("\tInfrastructure loaded ($(RN.nb) blocks and $(RN.ns) stations)")
    RN
end

"""
    loadFleet()::Fleet

Loads the train fleet and schedules from the `timetable.csv` file.

- Reads train schedules (including rotations if provided).
- Initializes each train's dynamic state and delay dictionary.

# Returns
- `Fleet` object containing train information and schedules.
"""
function loadFleet()::Fleet

    file::String          = Opt["timetable_file"];
    rotation_file::String = Opt["rotation_file"];
    print_flow::Bool      = Opt["print_flow"];

    print_flow && @info("\tLoading fleet information")

    FL = Fleet(0,Dict{String, Train}())
    df = DataFrame(CSV.File(file, comment="#"))

    # df.duetime = dateToSeconds.(df.duetime)

    Trains = FL.train;

    Rot = Dict{String,String}();
    if isfile(rotation_file)
        Rot = Dict(CSV.File(rotation_file, comment="#"));
        print_flow && @info("\tRotations loaded");
    end

    # build the schedule for every train
    for r in eachrow(df)
        (train, bts, kind, direction, line, _distance, duetime) = r[:];

        str = Transit(
                train,
                bts,
                kind,
                string(line),
                direction,
                duetime
        )

        if !haskey(Trains, train)
            Trains[train] = Train(
                                train,
                                get(Rot, train, ""),
                                Transit[],
                                DynTrain(0,"",""),
                                Dict{String,Int}()
                            );
        end
        push!(Trains[train].schedule, str);
    end

    FL.n = length(Trains);
    #df = nothing; # free memory for a better world

    # initialize the delay on the blocks
    for train in keys(Trains)
        # be sure the schedule is sorted
        Schedule = Trains[train].schedule;
        issorted(Schedule) || sort!(Schedule);
    end

    print_flow && @info("\tFleet loaded ($(FL.n) trains)")

    return FL;
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
    loadDelays()::Vector{DataFrame}

Loads delay files from the `data/delays/` directory.

- Reads multiple delay files, each defining a delay scenario.
- Supports multi-scenario simulation.

# Returns
- A vector of DataFrames, where each DataFrame contains delay data.

"""
function loadDelays()::Vector{DataFrame}

    print_imposed_delay::Bool = Opt["print_imposed_delay"];
    multi_simulation::Bool    = Opt["multi_simulation"];
    repo::String              = Opt["imposed_delay_repo_path"];

    occursin(r"/$", repo) || (repo *= "/"); # add slash to the folder name if not present
    
    delays_array = DataFrame[];

    files = sort(read_non_hidden_files(repo));


    if isempty(files)
        print_imposed_delay && @info("No imposed delay file was found. Simulating without imposed delays.");
        return DataFrame[];
    end

    if multi_simulation
        for file in files
            delaydf = DataFrame(CSV.File(repo*file, comment="#"));
            push!(delays_array,delaydf);
        end
    else
        file = files[1];
        delaydf = DataFrame(CSV.File(repo*file, comment="#"));
        push!(delays_array, delaydf);
    end

    Opt["print_flow"] && @info("\tDelays loaded. The number of delay scenarios is: ",length(delays_array));

    return delays_array;
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

"""
    resetDelays(FL::Fleet)

Resets all delays for the train fleet to zero.

- Clears the `delay` dictionary for each train in the fleet.

# Arguments
- `FL::Fleet`: The fleet object containing train delay data.
"""
function resetDelays(FL::Fleet)
    print_imposed_delay = Opt["print_imposed_delay"];

    for Train in values(FL.train)
        Train.delay = Dict{String,Int}();
    end

    Opt["print_flow"] && println("Delays reset");

end

"""
    imposeDelays(FL::Fleet, df::DataFrame)::Nothing

Imposes delays on the train fleet using a DataFrame of delay values.

- Delays are applied to specific trains and blocks/stations as specified.
- Resets previous delays before applying new ones.

# Arguments
- `FL::Fleet`: The current fleet object.
- `df::DataFrame`: A DataFrame with `train`, `block`, and `delay` columns.
"""
function imposeDelays(FL::Fleet, df::DataFrame)::Nothing

    BLACKLIST = [""]; #["SB_29229"];

    print_imposed_delay::Bool = Opt["print_imposed_delay"];
    print_flow::Bool          = Opt["print_flow"];

    # reset the delays imposed in the previous simulation
    resetDelays(FL);

    # df = delays_array[simulation_id];

    for r in eachrow(df)
        (train, block, delay) = r;
        train ∈ BLACKLIST && continue;
        
        #o = split(block, "-");
        #if length(o) == 1 || o[1] == o[2] # it's a station
        #    block = replace(o[1], r"[ _]+" => "");
        #else
        #    # if the block is not a station we have to find to which line it belongs
        #    @warn "Delays on blocks other than stations [$block] is not implemented yet.";
        #end 

        FL.train[train].delay[block] = delay;

        if print_imposed_delay
            if occursin("-", block)
                println("Imposed $delay to train $train, at block $block.")
            else
                println("Imposed $delay to train $train, at station $block.")
            end
        end
    end

    print_flow && println("$(nrow(df)) Delays imposed");
    df = nothing;
end

"""
    initEvent(FL::Fleet)::Dict{Int, Vector{Transit}}

Initializes the event dictionary for the simulation.

- The event dictionary maps event times to a list of train transits scheduled at those times.
- Extracts the first transit event from each train's schedule.

# Arguments
- `FL::Fleet`: The fleet object containing train schedules.

# Returns
- A dictionary `Dict{Int, Vector{Transit}}` mapping times to train events.
"""
function initEvent(FL::Fleet)::Dict{Int,Vector{Transit}}

    E = Dict{Int,Vector{Transit}}()

    Opt["print_flow"] && @info("\tInitializing the event table")

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
