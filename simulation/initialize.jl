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

    #list of the tracks, for now just 5
    tracks=[5]
    #two directions wrt a track
    directions=[-1,1]

    fileblock = Opt["block_file"]
    df = DataFrame(CSV.File(fileblock, comment="#"))

    df_stations=filter(row -> (split(row.id,"-")[1] == split(row.id,"-")[2]), df)
    transform!(df_stations, :id => ByRow(x -> split(x,"-")[1]) => :bts)

    df_blocks=antijoin(df, df_stations, on = :id)
    transform!(df_blocks, :id => ByRow(x -> split(x,"-")[2]) => :ending_bts)
    transform!(df_blocks, :id => ByRow(x -> split(x,"-")[1]) => :starting_bts)


    if Opt["multi_stations_flag"] #the stations are used with the directionality of the tracks

        #handling the blocks first
        for i = 1:nrow(df_blocks)
            name = df_blocks.id[i]

            b = Block(
                    name,
                    # i,
                    df_blocks.tracks[i],
                    0,
                    Set{String}()
            )
            RN.nb += 1
            RN.blocks[name]=b

        end

        #handling stations
        for i = 1:nrow(df_stations)

            name = df_stations.id[i]
            bts=df_stations.bts[i]
            platforms=df_stations.tracks[i]

            #impossible station with only one plat
            if (platforms==1)
                # println("$bts has 1 platform,update to 2")
                println("WARNING: station $name has only one platform.")
                # platforms+=1
            end

            #number of directions taken into account
            n_dir=length(directions)

            #integer number of plats per direction
            n_plat=div(platforms,n_dir)

            #remaining plat in common
            common=platforms-n_dir*n_plat

            # #cycle over blocks ending in that station
            # df_blocksInStation=filter((row -> row.ending_bts == bts), df_blocks)
            dir2platforms=Dict()
            dir2trainscount=Dict()
            # trainInBlock2direction=Dict()
            # for j = 1:nrow(df_blocksInStation)
            #
            #     tracks=df_blocksInStation.tracks[j]
            #     start_bts=df_blocksInStation.starting_bts[j]
            #
            #     platforms-=tracks
            #
            # end

            #dictionaries for occupancy for every direction
            for direction in directions
                dir2platforms[direction]=n_plat
                dir2trainscount[direction]=0
            end

            #update of simulation: usa also common plats.
            if common > 0
                dir2platforms["common"]=common
            else
                dir2platforms["common"]=0
            end

            b = Block(
                    name,
                    # i,
                    dir2platforms,
                    dir2trainscount,
                    Set{String}()
            )



            RN.nb += 1
            RN.blocks[name]=b
            # push!(RN.nodes[from].child, to)
            # push!(RN.nodes[to].parent, from)
        end



    else#normal blocks
        for i = 1:nrow(df)
            name = df.id[i]

            name_split = split(name, '-')
            if name_split[1]==name_split[2]
                # println(name)
            end

            b = Block(
                    name,
                    # i,
                    df.tracks[i],
                    0,
                    Set{String}()
            )
            RN.nb += 1
            RN.blocks[name]=b
            # push!(RN.nodes[from].child, to)
            # push!(RN.nodes[to].parent, from)
        end
    end
    df = nothing # explicitly free the memory

    RN.blocks[""] = Block( # the null block
                        "",
                        0,
                        0,
                        Set{String}()
    )



    Opt["print_flow"] && println("Infrastructure loaded")
    RN
end



function loadFleet()::Fleet
    """takes the timetable.csv file and loads the Fleet """
    file = Opt["timetable_file"]
    trains_info_file=Opt["trains_info_file"]

    Opt["print_flow"] && println("Loading fleet information")

    FL = Fleet(0,Dict{String, Train}())
    df = DataFrame(CSV.File(file, comment="#"))

    unique_trains=unique(df.trainid)

    #take direction from the file
    if isfile(trains_info_file)
        train2dir=CSV.File(trains_info_file) |> Dict
    elseif Opt["multi_stations_flag"]
        println("multi platforms activated but no info un usage, add file and restart")
        exit()
    else
        train2dir=Dict(zip(unique_trains, zeros(length(unique_trains))))
    end

    block=String

    #right now the train track is only n.5
    track=5



    for train in unique_trains

        df2=filter(row -> (row.trainid == train), df) #provo a usare subset
        nrows=nrow(df2)

        #restore original name from poppers
        if occursin("_pop", train)

            r=collect(findfirst("_pop", train))

            unpopped = train[1:r[1]-1]

            # println("$train, removing: $unpopped")
        else
            unpopped=train
        end


        direction=train2dir[unpopped]


        for i in 1:nrows


            bts=df2.opid[i]

            # trainid=string(df2.trainid[i])
            duetime = dateToSeconds(df2.duetime[i])
            str = Transit(
                    train,
                    df2.opid[i],
                    df2.kind[i],
                    duetime
            )

            if i < nrows
                next_bts=df2.opid[i+1]
                block=bts*"-"*next_bts
            end


            if !haskey(FL.train, train)

                get!(FL.train, train,
                        Train(train,track,direction, [str],
                            DynTrain(0,"",""),Dict(block=>0)))
                # get!(FL.train, trainid,
                #         Train(trainid, [str],
                #             DynTrain(0,"","",0,0)))
            else
                push!(FL.train[train].schedule, str)
                # println(i,nrows)
                FL.train[train].delay[block]=0
            end

        end

    end


    FL.n = length(FL.train)
    df = nothing
    df2= nothing


    for train in keys(FL.train)
        !issorted(FL.train[train].schedule) && sort!(FL.train[train].schedule)#(println("here!");exit())#()
    end

    Opt["print_flow"] && println("Fleet loaded ($(FL.n) trains)")
    return FL

    end







function read_non_hidden_files(repo)::Vector{String}
    return filter(!startswith(".") ∘ basename, readdir(repo))
end

#customized sorting, for correctly sorting strings based on last digits
function custom_cmp(x::String)
    arr_str = rsplit(x, "_",limit=2)
    str1, _ = arr_str[1], arr_str[2]
    number_idx = findlast(isdigit, arr_str[2])
    num,str2 = SubString(arr_str[2], 1, number_idx), SubString(arr_str[2], number_idx+1, length(arr_str[2]))
    return str1,parse(Int, num)
end

function loadDelays()::Tuple{Vector{DataFrame},Int}
    """Takes all the delay files in the data/delays/ directory
    and loads it in a vector of dataframes;
    each df defines a different simulation to be done """
    print_imposed_delay = Opt["print_imposed_delay"];

    n=0
    delays_array=DataFrame[];

    repo = Opt["imposed_delay_repo_path"]
    files=sort!(read_non_hidden_files(repo), by = custom_cmp)


    if isempty(files)
        print_imposed_delay && println("No imposed delay file was found. Simulating without imposed delays.")
        return (delays_array,1);
    end

    for file in files
        delay= DataFrame(CSV.File(repo*file, comment="#"))
        push!(delays_array,delay)
    end

    #print(delays_array)
    n=length(delays_array)
    Opt["print_flow"] && println("Delays loaded. The number of files in data/delays/ is: ",n)
    delay=nothing

    return (delays_array,n)
end

function resetDelays(FL::Fleet,delays_array::Vector{DataFrame},simulation_id::Int)
    """takes the vector of df,
    resets to 0 the delays imposed to the previews simulation """
    print_imposed_delay = Opt["print_imposed_delay"];

    df = delays_array[simulation_id-1];


    for i = 1:nrow(df)
        (train, block, delay) = df[i,:];

        FL.train[train].delay[block]=0
        if print_imposed_delay
            println("Reset $delay to train $train, at block $block.")
        end
    end

    Opt["print_flow"] && println("$(nrow(df)) Delays reset");
    df = nothing;

end

function imposeDelays(FL::Fleet,delays_array::Vector{DataFrame},simulation_id::Int)
    """imposes the delays for the actual simulation """
    print_imposed_delay = Opt["print_imposed_delay"];


    if simulation_id>1
        resetDelays(FL,delays_array,simulation_id);
    end

    df = delays_array[simulation_id];

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


function initEvent(FL::Fleet)::Dict{Int,Vector{Transit}}

    """Creates the Event dict,
     having times as keys and events in that time as values """
    E = Dict{Int,Vector{Transit}}()

    #TB = generateTimetable(FL)

    Opt["print_flow"] && println("Initializing the event table")

    S = Set{String}() # trains circulating

    for trainid in keys(FL.train)

        Opt["print_train_list"] && println("\tTrain $trainid")

        for s in FL.train[trainid].schedule #fl.train[trainid].schedule --> vector of transits

            duetime = s.duetime

            if trainid ∉ S # add new train in the current day events

                get!(E,duetime,Transit[])
                push!(E[duetime], s)
                push!(S, trainid)
                #println("New train $trainid starting at $opid")
            end

        end
    end

    E
end
