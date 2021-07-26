"""
This file contains all the functions that have to initialize the system.
For example, loading the network, the block characteristics, the timetables
"""

function loadNetwork(fileOP::String, fileB::String)
    RN = Network()
    loadOPoints(fileOP, RN)
    loadBlocks(fileB, RN)
    RN
end

function loadOPoints(file::String, RN::Network)
    df = DataFrame(CSV.File(file))

    for i = 1:nrow(df)
        name = string(df.id[i])
        op = OPoint(
                name,
                i,
                df.lat[i],
                df.long[i],
                String[],
                String[]
        )
        RN.n += 1
        RN.nodes[name]=op
    end
    df = nothing # explicitly free the memory
end


function loadBlocks(fileblock::String, RN::Network)

    df = DataFrame(CSV.File(fileblock))

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
                df[i,:isStation]
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

function loadTimetable(file::String="data/timetable.csv")
    TB = TimeTable(0, Dict{Int,Transit}())
    df = DataFrame(CSV.File(file))
    for i = 1:nrow(df)
        tr = Transit(
                string(df.trainid[i]),
                df.opid[i],
                df.kind[i],
                dateToSeconds(df.duetime[i])
        )
        TB.n += 1
        TB.timemap[dateToSeconds(df.duetime[i])] = tr
    end
    df = nothing
    println("Timetable loaded")
    TB
end

function loadFleet(file::String="data/timetable.csv")
    FL = Fleet(0,Dict{String, Train}())
    df = DataFrame(CSV.File(file))
    for i = 1:nrow(df)
        #trainid,opid,kind,duetime = Tuple(df[i,:])
        trainid=string(df.trainid[i])
        duetime = dateToSeconds(df.duetime[i])
        str = sTransit(
                df.opid[i],
                df.kind[i],
        )
        get!(FL.train, trainid, str)
        # FL.train[trainid].trainid = trainid
        # FL.train[trainid].schedule[duetime] = str
    end
    FL.n = length(FL.train)
    df = nothing
    println("Fleet loaded")
    return FL
end
