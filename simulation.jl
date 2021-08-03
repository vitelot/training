"""
simulation engine
"""
function simulation(RN::Network, FL::Fleet)
    S  = Set{String}() # running trains
    TrainOnBlock = Dict{String,String}()

    Event = initEvent(FL) # initialize the events with the departure of new trains

    t = t_initial = minimum(keys(Event)) - 1
    t_final = maximum(keys(Event))

    while(t<=t_final) # a for loop does not fit here since we need to recalculate t_final in the loop
        t += 1
        if haskey(Event, t)
            for transit in Event[t]

                trainid = transit.trainid
                opid = transit.opid
                kind = transit.kind
                duetime = transit.duetime
                #println("Train $train passed through $opid at $t sec ($kind)")

                if t<duetime # wow, we arrived earlier
                    println("Train $trainid is $(duetime-t) seconds early at $opid ($kind)")
                    if kind == "Abfahrt"
                        # we cannot leave earlier than expected from a station
                        get!(Event, duetime, Transit[])
                        push!(Event[duetime], transit)
                        t_final = max(duetime, t_final) # cures the problem with the last train overnight
                        continue;
                    end

                elseif t>duetime # ouch, we are late
                    println("Train $trainid is $(t-duetime) seconds late at $opid ($kind)")

                else # we are perfectly on time
                    println("Train $trainid is on time at $opid ($kind)")
                end

                if trainid ∉ S # new train in the current day
                    push!(S,trainid)
                    println("New train $trainid starting at $opid")
                end

                # we are in opid and would like to move to nextopid travelling on block "opid-nextopid"
                train = FL.train[trainid]
                train.dyn.opn += 1
                nop = train.dyn.opn # number of opoints passed
                if nop < length(train.schedule)
                    nextopid = train.schedule[nop+1].opid
                    train.dyn.nextBlock = opid*"-"*nextopid

                    if (get!(TrainOnBlock, train.dyn.nextBlock, "") == "") || (opid==nextopid) #next block is free or is a station!!!! Let's goooo!!!
                        TrainOnBlock[train.dyn.nextBlock] = trainid # we occupy the block
                        TrainOnBlock[train.dyn.currentBlock] = ""
                        train.dyn.currentBlock = train.dyn.nextBlock

                        train.dyn.nextBlockDueTime = train.schedule[nop+1].duetime - train.schedule[nop].duetime

                        # nice way of listing blocks and travelling times by train
                        #println("#$(train.dyn.nextBlock),$(train.dyn.nextBlockDueTime),$trainid")

                        train.dyn.nextBlockRealTime = floor(Int, train.dyn.nextBlockDueTime * myRand())
                        tt = t + train.dyn.nextBlockRealTime
                        get!(Event, tt, Transit[])
                        push!(Event[tt], train.schedule[nop+1])
                        t_final = max(tt, t_final) # cures the problem with the last train overnight
                    else
                        println("There is train $(TrainOnBlock[train.dyn.nextBlock]) on the next block [$(train.dyn.nextBlock)]. Train $trainid needs to wait.")
                        get!(Event, t+1, Transit[])
                        push!(Event[t+1], train.schedule[nop])
                        train.dyn.opn -= 1
                    end
                else
                    println("Train $trainid ended in $opid")
                    TrainOnBlock[train.dyn.currentBlock] = ""
                    pop!(S,trainid)
                    train.dyn.opn = 0 # reset the train for further use
                end
            end
        end

    end

end
