include("extern.jl")
include("initialize.jl")
include("functions.jl")

function main()
    debuglvl = 2
    RN = loadInfrastructure()
    FL = loadFleet()

    S  = Set{String}() # running trains

    Event = initEvent(FL) # initialize the events with the departure of new trains

    for t = 1:86400

        if haskey(Event, t)
            for transit in Event[t]

                trainid = transit.trainid
                opid = transit.opid
                kind = transit.kind
#                printDebug(debuglvl,"Train $train passed through $opid at $t sec ($kind)")
                if t<transit.duetime
                    println("Train $trainid is $(transit.duetime-t) seconds early at $opid ($kind)")
                    if kind == "Abfahrt"
                        # we cannot leave early from a station
                        get!(Event, transit.duetime, Transit[])
                        push!(Event[transit.duetime], transit)
                        continue;
                    end
                elseif t>transit.duetime
                    println("Train $trainid is $(t-transit.duetime) seconds late at $opid ($kind)")
                else
                    println("Train $trainid is on time at $opid ($kind)")
                end

                if trainid ∉ S # new train in the current day
                    push!(S,trainid)
                    println("New train $trainid starting at $opid")
                end

                train = FL.train[trainid]
                train.dyn.opn += 1
                nop = train.dyn.opn
                if nop < length(train.schedule)
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
    sort(Event)
end

main()
