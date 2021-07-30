include("extern.jl")
include("initialize.jl")
include("functions.jl")

function main()
    debuglvl = 2
    RN = loadInfrastructure()
    FL = loadFleet()
    TB = generateTimetable(FL)

    S  = Set{String}() # running trains

    for t = 1:86400
        D = TB.timemap


        if haskey(D, t # there may be more trains at time t
            for transit in D[t]

                train = transit.trainid
                opid = transit.opid
                kind = transit.kind
                printDebug(debuglvl,"Train $train passed through $opid at $t sec ($kind)")

                if train ∉ S # new train in the current day
                    push!(S,train)
                    println("New train $train starting at $opid")
                else
                    if kind == "Ende"
                        println("Train $train arrived at $opid")
                        pop!(S,train)
                    end
                end
            end
        end
    end

end

main()
