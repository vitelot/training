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
end

function loadTimetable()


end
