"""
This file contains all the functions that have to initialize the system.
For example, loading the network, the block characteristics, the timetables
"""

function loadNetwork(fileOP::String, fileB::String)::Network
    RN = Network()
    #loadOPoints!(fileOP, RN)
    loadBlocks!(fileB, RN)
    RN
end

function loadOPoints!(file::String, RN::Network)
    df = DataFrame(CSV.File(file, comment="#"))

    for i = 1:nrow(df)
        name = string(df.id[i])
        op = OPoint(
                name,
                i,
                df.lat[i],
                df.long[i],
                String[],
                String[],
                false
        )
        RN.n += 1
        RN.nodes[name]=op
    end
    df = nothing # explicitly free the memory
end


function loadBlocks!(fileblock::String, RN::Network)

    df = DataFrame(CSV.File(fileblock, comment="#"))

    for i = 1:nrow(df)
        name = df.id[i]
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
    df = nothing # explicitly free the memory

    RN.blocks[""] = Block( # the null block
                        "",
                        0,
                        0,
                        Set{String}()
    )
end

function loadInfrastructure()::Network
    RN = loadNetwork("data/betriebstellen.csv", "data/blocks.csv")
    Opt["print_flow"] && println("Infrastructure loaded")
    RN
end

function loadFleet(file::String="data/timetable.csv")::Fleet

    Opt["print_flow"] && println("Loading fleet information")
    Opt["TEST"] && (file="data/test.csv")

    FL = Fleet(0,Dict{String, Train}())
    df = DataFrame(CSV.File(file, comment="#"))
    for i = 1:nrow(df)
        #trainid,opid,kind,duetime = Tuple(df[i,:])
        trainid=string(df.trainid[i])
        duetime = dateToSeconds(df.duetime[i])
        str = Transit(
                trainid,
                df.opid[i],
                df.kind[i],
                duetime
        )
        if !haskey(FL.train, trainid)
            get!(FL.train, trainid,
                    Train(trainid, [str],
                        DynTrain(0,"","",0,0)))
        else
            push!(FL.train[trainid].schedule, str)
        end

    end
    FL.n = length(FL.train)
    df = nothing
    Opt["print_flow"] && println("Fleet loaded ($(FL.n) trains)")
    return FL
end

function initEvent(FL::Fleet)::Dict{Int,Vector{Transit}}

    E = Dict{Int,Vector{Transit}}()

    TB = generateTimetable(FL)

    Opt["print_flow"] && println("Initializing the event table")

    S = Set{String}() # trains circulating

    D = TB.timemap
    t_initial = minimum(keys(D))
    t_final = maximum(keys(D))

    for t = t_initial:t_final
        if haskey(D, t)
            for transit in D[t] # there may be more trains at time t

                trainid = transit.trainid

                if trainid ∉ S # add new train in the current day events
                    get!(E,t,Transit[])
                    push!(E[t], transit)
                    push!(S, trainid)
                    #println("New train $trainid starting at $opid")
                end
            end
        end
    end
    E
end

function loadOptions(file::String="run/par.ini")
    df  = DataFrame(CSV.File(file, delim="=", comment="#", type=String))
    for i = 1:nrow(df)
        key = df.key[i] ; val = df.value[i]
        if(key == "debug_lvl") Opt[key] = parse(Int, val)
        elseif(key=="minrnd") Opt[key] = parse(Float64, val)
        elseif(key=="maxrnd") Opt[key] = parse(Float64, val)
        elseif(key=="print_options") Opt[key] = parse(Bool, val)
        elseif(key=="print_flow") Opt[key] = parse(Bool, val)
        elseif(key=="print_train_status") Opt[key] = parse(Bool, val)
        elseif(key=="print_new_train") Opt[key] = parse(Bool, val)
        elseif(key=="print_train_wait") Opt[key] = parse(Bool, val)
        elseif(key=="print_train_end") Opt[key] = parse(Bool, val)
        elseif(key=="print_train_fossile") Opt[key] = parse(Bool, val)
        elseif(key=="print_train_list") Opt[key] = parse(Bool, val)
        elseif(key=="TEST") Opt[key] = parse(Bool, val)
        else println("WARNING: input parameter $key does not exist")
        end
    end
    df = nothing
    if Opt["print_options"]
        println("########################")
        println("List of input parameters")
        for (i,j) in Opt
            println("$i = $j")
        end
        println("########################")
    end
end
