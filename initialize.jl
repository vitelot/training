"""
This file contains all the functions that have to initialize the system.
For example, loading the network, the block characteristics, the timetables
"""

function loadNetwork(fileOP::String, fileB::String)
    RN = Network()
    loadOPoints!(fileOP, RN)
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
        from = df.from[i]
        to = df.to[i]
        name = "$from-$to"
        b = Block(
                name,
                i,
                df[i,:minT],
                df[i,:dueT],
                # [],
                # [],
                df[i,:isStation],
                ""
        )
        RN.nb += 1
        RN.blocks[name]=b
        push!(RN.nodes[from].child, to)
        push!(RN.nodes[to].parent, from)
    end
    df = nothing # explicitly free the memory
end

# function loadBlockConnections!(RN::Network, filenet::String)
#     df = DataFrame(CSV.File(filenet))
#     for i = 1:nrow(df)
#         fromID = string(df[i, :from])
#         toID = string(df[i, :to])
#         fromIDX = RN.IDtoIDX[fromID]
#         toIDX = RN.IDtoIDX[toID]
#         push!(RN.blocks[toIDX].parent, fromIDX)
#         push!(RN.blocks[fromIDX].child, toIDX)
#     end
# end

function loadInfrastructure()
    RN = loadNetwork("data/betriebstellen.csv", "data/blocks.csv")
    println("Infrastructure loaded")
    RN
end

function loadFleet(file::String="data/timetable.csv")

    println("Loading fleet information")

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
    println("Fleet loaded ($(FL.n) trains)")
    return FL
end

function initEvent(FL::Fleet)
    E = Dict{Int,Vector{Transit}}()

    TB = generateTimetable(FL)

    println("Initializing the event table")

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
