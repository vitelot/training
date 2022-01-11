"""
simulation engine
"""
function simulation(RN::Network, FL::Fleet)::Bool

    # get the required options
    maxrnd = Opt["maxrnd"]
    minrnd = Opt["minrnd"]
    print_train_status = Opt["print_train_status"]
    print_new_train = Opt["print_new_train"]
    print_train_wait = Opt["print_train_wait"]
    print_train_end = Opt["print_train_end"]
    print_train_fossile = Opt["print_train_fossile"]
    print_elapsed_time = Opt["print_elapsed_time"]
    print_tot_delay = Opt["print_tot_delay"]

    ##variabili

    #t in events that are between an evaluation of stuck sim and another
    t_evaluated=0
    #minimum number of t for evaluating
    min_t_evaluated=10
    #time interval in seconds between an evaluation of stuck and another
    stuck_interval=3000

    old_status = status = ""; # trains going around, used to get stuck status




    S  = Set{String}() # running trains

    BK = RN.blocks # Dict{String,Block}

    Event = initEvent(FL) # initialize the events with the departure of new trains

    # println("Event Dict is : ", Event[63684945420])
    #
    # Event2 = initEvent(FL) # initialize the events with the departure of new trains
    #
    # println("Event Dict 2 is : ", Event2[63684945420])
    #
    # println("Are the event dict the same  : ", isequal(Event,Event2))

    totDelay = 0 #####


    t0 = t = minimum(keys(Event)) - 1
    t_final=t_final_starting = maximum(keys(Event))

    print_elapsed_time && println("t final starting is $t_final_starting")



    while(t<=t_final) # a for loop does not fit here since we need to recalculate t_final in the loop

        t += 1
        if haskey(Event, t)

            t_evaluated+=1
            print_elapsed_time && println("Elapsed time $(t-t0) simulated seconds")


            for transit in Event[t]

                trainid = transit.trainid
                current_opid = transit.opid
                kind = transit.kind
                duetime = transit.duetime


                #arrived early, appending event for next time and continue,skipping this transit
                if t<duetime # wow, we arrived earlier
                    print_train_status && println("Train $trainid is $(duetime-t) seconds early at $current_opid ($kind)")
                    if kind == "Abfahrt"
                        # we cannot leave earlier than expected from a station
                        get!(Event, duetime, Transit[])
                        push!(Event[duetime], transit)
                        t_final = max(duetime, t_final) # cures the problem with the last train overnight
                        continue;
                    end
                end


                print_train_status && println("Train $trainid is $(t-duetime) seconds late at $current_opid ($kind)")



                if trainid ∉ S # new train in the current day
                    push!(S,trainid)
                    print_new_train && println("New train $trainid starting at $current_opid at time $t")
                end

                # we are in current_opid and would like to move to nextopid travelling on block "current_opid-nextopid"
                train = FL.train[trainid]
                train.dyn.n_opoints_visited += 1
                n_op = train.dyn.n_opoints_visited # number of opoints passed
                if n_op < length(train.schedule)
                    nextopid = train.schedule[n_op+1].opid


                    nextBlockid = current_opid*"-"*nextopid

                    # if !haskey(BK, nextBlockid)
                    #     println("ERROR: Block $nextBlockid is inexistent");
                    #     pprintln(train);
                    #     exit();
                    # end

                    nextBlock = BK[nextBlockid]

                    currentBlock = BK[train.dyn.currentBlock]

                    if nextBlock.nt < nextBlock.tracks # if there are less trains than the number of available tracks

                        nextBlock.nt += 1
                        push!(nextBlock.train, trainid)

                        if currentBlock.id != ""
                            currentBlock.nt -= 1
                            pop!(currentBlock.train, trainid)
                        end

                        train.dyn.currentBlock = nextBlockid

                        nextBlockDueTime = train.schedule[n_op+1].duetime - train.schedule[n_op].duetime
                        #"""train.dyn.nextBlockDueTime = train.schedule[n_op+1].duetime - train.schedule[n_op].duetime"""

                        # nice way of listing blocks and travelling times by train
                        #println("#$(train.dyn.nextBlock),$(train.dyn.nextBlockDueTime),$trainid")

                        nextBlockRealTime = floor(Int, nextBlockDueTime * myRand(minrnd,maxrnd))
                        #"""train.dyn.nextBlockRealTime = floor(Int, nextBlockDueTime * myRand(minrnd,maxrnd))"""

                        delay_imposed=train.schedule[n_op].imposed_delay.delay
                        tt = t + nextBlockRealTime + delay_imposed;

                        print_train_status && (delay_imposed > 0 && println("A delay to train $trainid is imposed in  block [$nextBlockid]; Opt[imposed_delay_repo_path] is $(Opt["imposed_delay_repo_path"]) "))

                        get!(Event, tt, Transit[])
                        push!(Event[tt], train.schedule[n_op+1])
                        t_final = max(tt, t_final) # cures the problem with the last train overnight


                    else
                        print_train_wait && println("Train $trainid needs to wait. Next block [$nextBlockid] is full [$(nextBlock.train)].")
                        tt = t+1
                        get!(Event, tt, Transit[])
                        push!(Event[tt], train.schedule[n_op])
                        train.dyn.n_opoints_visited -= 1
                        t_final = max(tt, t_final)


                    end



                    # isdir(Opt["imposed_delay_repo_path"]) && ((t_final > t_final_starting+3000) &&
                    #     (println("Simulation is stuck with times t_finals $t_final and $t_final_starting and the number of events exceeds 300 seconds for 1 day simulation, returning 1. ");
                    #     Event = nothing;return true))
                else
                    if length(train.schedule) > 1 # yes, there are fossile trains with one entry only
                        print_train_end && (((t-duetime)> 0) && println("Train $trainid ended in $current_opid with a delay of $(t-duetime) seconds at time $t seconds"))
                        BK[train.dyn.currentBlock].nt -= 1
                        pop!(BK[train.dyn.currentBlock].train, trainid)
                        if t>duetime
                            totDelay += (t-duetime);
                        end
                        #Opt["print_tot_delay"] && println("Delay $(t-duetime) seconds") ) #####
                    else
                        print_train_fossile && println("Train $trainid is a fossile")
                    end
                    pop!(S,trainid)
                    #train.dyn = DynTrain(0,"","") #.n_opoints_visited = 0 # reset the train for further use
                    # train.dyn.currentBlock = train.dyn.nextBlock = ""
                end
            end
        end#haskey

        if (t%stuck_interval == 0) && (t_evaluated > min_t_evaluated) && (t > t_final_starting) #check if every 3000 seconds and if has evaluated enough events, if sim is stuck


            # check stuck func here // Vitus
            status = netStatus(S,BK,hashing=false);
            if (old_status == status) && (!isempty(status))
                println("Simulation is stuck with times t_finals $t_final and $t_final_starting")
                println("t is $t ;")
                println("status is ",status);
                #Event = nothing; #don't need to do that. it will be garbage collected.
                return true;
            end
            t_evaluated=0
            old_status = status;
        end
        delete!(Event, t); # we finished all the tasks at time t and free up memory. 
    end
    #Event = Dict{Int,Vector{Transit}}(); #don't need to do that. it will be garbage collected.
    Opt["print_flow"] && println("Simulation ended.")
    print_tot_delay && println("Total delay at the end of simulation is $totDelay")
    return false
end
