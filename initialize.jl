"""
This file contains all the functions that have to initialize the system.
For example, loading the network, the block characteristics, the timetables
"""
function loadBlockInfo(fileblock::String)

    RN = Network()
    df = DataFrame(CSV.File(fileblock))

    for i = 1:nrow(df)
        b = Block(
                string(df[i,:id]),
                i,
                df[i,:minT],
                df[i,:dueT],
                [],
                [],
                df[i,:isStation]
        )
        RN.nBlocks += 1
        push!(RN.blocks, b)
        get!(RN.IDtoIDX, b.id, i)
    end
    df = nothing # explicitly free the memory
    RN
end

function loadBlockConnections!(RN::Network, filenet::String)
    df = DataFrame(CSV.File(filenet))
    for i = 1:nrow(df)
        fromID = string(df[i, :from])
        toID = string(df[i, :to])
        fromIDX = RN.IDtoIDX[fromID]
        toIDX = RN.IDtoIDX[toID]
        push!(RN.blocks[toIDX].parent, fromIDX)
        push!(RN.blocks[fromIDX].child, toIDX)
    end
end

function loadInfrastructure()
    RN = loadBlockInfo("data/blocks.csv")
    loadBlockConnections!(RN, "data/network.csv")
    RN
end
