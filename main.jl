include("extern.jl")
include("initialize.jl")
include("functions.jl")

function main()
    debuglvl = 2
    RN = loadInfrastructure()
    FL = loadFleet()
    TB = generateTimetable(FL)

    S  = Set{String}() # running trains

    Event = initEvent(TB) # initialize the events with the departure of new trains

    for t = 1:86400
        D = TB.timemap

        if haskey(Event, t)
            for transit in Event[t]

                trainid = transit.trainid
                opid = transit.opid
                kind = transit.kind
#                printDebug(debuglvl,"Train $train passed through $opid at $t sec ($kind)")


                if trainid ∉ S # new train in the current day
                    push!(S,trainid)
                    println("New train $trainid starting at $opid")
                end

                train = FL.train[trainid]
                train.dyn.opn += 1
                nop = train.dyn.opn
                if length(train.schedule) <= nop+1
                    nextopid = train.schedule[nop+1].opid
                    train.dyn.currentBlock = opid*"-"*nextopid
                    train.dyn.currentBlockDueTime = train.schedule[nop+1].duetime - train.schedule[nop].duetime
                    train.dyn.currentBlockRealTime = floor(Int, train.dyn.currentBlockDueTime * rand(0.9:0.01:1.1))
                    tt = t + train.dyn.currentBlockRealTime
                    get!(Event, tt, Transit[])
                    push!(Event[tt], train.schedule[nop+1])
                else
                    println("Train $trainid arrived at $opid")
                    pop!(S,trainid)
                end
            end
        end
    end

end

main()
