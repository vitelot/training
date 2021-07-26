include("extern.jl")
include("initialize.jl")
include("functions.jl")

function main()

    RN = loadInfrastructure()
    TB = loadTimetable()
    for i = 1:86400
        D = TB.timemap
        if haskey(D, i)
            t = D[i]
            train = t.trainid
            opid = t.opid
            kind = t.kind
            println("Train $train passed through $opid")
        end
    end
    loadFleet()
end

main()
