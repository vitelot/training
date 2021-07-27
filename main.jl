include("extern.jl")
include("initialize.jl")
include("functions.jl")

function main()

    RN = loadInfrastructure()
    FL = loadFleet()
    TB = generateTimetable(FL)

    for i = 1:86400
        D = TB.timemap
        if haskey(D, i)
            for t in D[i]

                train = t.trainid
                opid = t.opid
                kind = t.kind
                println("Train $train passed through $opid at $i sec ($kind)")
            end
        end
    end

end

main()
