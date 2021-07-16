"""
This file contains all the functions that have to initialize the system.
For example, loading the network, the block characteristics, the timetables
"""
function loadNetwork()
    fileblock = "data/blocks.csv"
    fileNet = "data/network.csv"

    RN = Network(0,[])
    df = DataFrame(CSV.File(fileblock))

    for i = 1:nrow(df)
        b = Block(
                df[i,:id],
                df[i,:minT],
                df[i,:dueT],
                [],
                [],
                false
        )
        RN.nBlocks += 1
        push!(RN.blocks, b)
    end
    RN
end
