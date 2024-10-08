"""
simulation engine
returns true if trains get stuck
"""
function simulation(RN::Network, FL::Fleet, sim_id::Int=0)::Bool

    # get the required options
    print_flow              = Opt["print_flow"];
    print_notifications     = Opt["print_notifications"];
    print_train_status      = Opt["print_train_status"];
    print_new_train         = Opt["print_new_train"];
    print_train_wait        = Opt["print_train_wait"];
    print_train_end         = Opt["print_train_end"];
    print_train_fossile     = Opt["print_train_fossile"];
    print_elapsed_time      = Opt["print_elapsed_time"];
    print_tot_delay         = Opt["print_tot_delay"];
    save_timetable          = Opt["save_timetable"];
    save_timetable_railml   = Opt["save_timetable_railml"];
    print_rot               = Opt["print_rotations"];
    catch_conflicts         = Opt["catch_conflict"];
    use_buffering_time      = Opt["use_buffering_time"];
    output_path             = Opt["output_path"]
    ##variabili

    #t in events that are between an evaluation of stuck sim and another
    t_evaluated = 0;
    #minimum number of t for evaluating
    min_t_evaluated = 10;
    #time interval in seconds between an evaluation of stuck and another
    stuck_interval = 3000;

    ROTATION_WAITING_TIME   = 120; # time to wait for a dependent rotation
    MAXIMUM_HALT_AT_STATION = 120; # Wait at most this amount of seconds before leaving
    MINIMUM_HALT_AT_STATION = 24; # Wait at least this amount of seconds before leaving
    TIME_TO_CHECK_FOR_FREE_BLOCK = 10; # Shifts the transit this amount of seconds untill the block is free

    old_status = status = ""; # trains going around, used to get stuck status


    if save_timetable || save_timetable_railml
        if sim_id == 0
            #outfilename = "../simulation/data/timetable_simulation";
            outfilename = "$(output_path)/timetable_simulation";
        else
            paddedsimid = lpad(sim_id,4,"0");
            #outfilename = "../simulation/data/timetable_simulation_$(paddedsimid)";
            outfilename = "$(output_path)/timetable_simulation_$(paddedsimid)";
        end

        # out_file = open(outfilename, "w");
        # println(out_file,"trainid,opid,kind,direction,line,t_scheduled,t_real");
        df_timetable = DataFrame(trainid=String[], opid=String[], kind=String[], direction=Int[],
                            line=String[], t_scheduled=Int[], t_real=Int[]);
    end

    S  = Set{String}(); # running trains

    BK = RN.blocks; # Dict{blockid,structure}
    ST = RN.stations; # Dict

    Event = initEvent(FL); # initialize the events with the departure of new trains
    # @warn "just exit for a test; saving the initial event table to file Events.txt";
    # open("../simulation/data/Events.txt", "w") do OUTtest
    #     pprintln(OUTtest, Event);
    # end
    # exit();

    totDelay = 0;

    t0 = t = minimum(keys(Event)) - 1;
    t_final=t_final_starting = maximum(keys(Event))

    print_elapsed_time && println("t final starting is $t_final_starting")

    while(t<=t_final) # a for loop does not fit here since we need to recalculate t_final in the loop

        t += 1
        if haskey(Event, t)

            t_evaluated += 1;
            print_elapsed_time && println("Elapsed time $(t-t0) simulated seconds");

            for transit in Event[t]

                trainid      = transit.trainid;
                current_opid = transit.opid;
                kind         = transit.kind;
                line         = transit.line;
                direction    = transit.direction;
                duetime      = transit.duetime;

                #arrived early, appending event for next time and continue,skipping this transit
                if t<duetime # wow, we arrived earlier
                    print_train_status && println("Train $trainid is $(duetime-t) seconds early at $current_opid ($kind) but has to wait to leave on schedule")
                    if kind == "d" || kind=="b" # departure or beginn
                        # we cannot leave earlier than expected from a station
                        get!(Event, duetime, Transit[])
                        push!(Event[duetime], transit)
                        t_final = max(duetime, t_final) # cures the problem with the last train overnight
                        continue;
                    end
                end

                print_train_status && (t-duetime>0) &&
                    println("Train $trainid is $(t-duetime) seconds late at $current_opid ($kind)");

                train = FL.train[trainid];

                if trainid ∉ S # new train in the current day
                    # if its dependence has not yet arrived, delay the departure
                    if in(train.dependence, S)
                        get!(Event, t+ROTATION_WAITING_TIME, Transit[]);
                        push!(Event[t+ROTATION_WAITING_TIME], train.schedule[1]);
                        print_rot && println("Train $trainid cannot start because $(train.dependence) did not arrive. $t");
                        continue;
                    end

                    push!(S,trainid);
                    print_new_train && println("New train $trainid starting at $current_opid at time $t");
                end

                # we are in current_opid and would like to move to nextopid travelling on block "current_opid-nextopid"
                train.dyn.n_opoints_visited += 1;
                n_op = train.dyn.n_opoints_visited; # number of opoints passed

                c = count('-', train.dyn.currentBlock);
                if c == 2 # it's a block
                    currentBlock = BK[train.dyn.currentBlock]; # e.g. "HGZ1-HG-22201"
                elseif c==0 # it's a station
                    currentBlock = ST[train.dyn.currentBlock]; # e.g. "WIE"
                else
                    @warn "Strange block/station id: $(train.dyn.currentBlock)";
                end

                if n_op < length(train.schedule)
                    nop1 = n_op+1;
                    nextopid = train.schedule[nop1].opid;
                    # nextline = train.schedule[nop1].line;
                    # nextdirection = train.schedule[nop1].direction;
    
                    # println(trainid);

                    if current_opid == nextopid
                        nextBlockid = current_opid;
                        naked_nextBlockid = current_opid;
                        nextBlock = ST[nextBlockid]; # it's a station
                    else
                        nextBlockid = current_opid*"-"*nextopid*"-"*line;
                        naked_nextBlockid = current_opid*"-"*nextopid; # nextBlockid without line
                        # some blocks do not exist on the starting op line and we find one that fits
                        if !haskey(BK, nextBlockid)
                            print_notifications && @info "\tBlock $nextBlockid not found on train $trainid";
                            (bfrom,bto,bline) = split(nextBlockid, "-");
                             bblk = string(bfrom,"-",bto);
                             blkfriend = filter(startswith(bblk), collect(keys(BK)));
                             if length(blkfriend) == 1
                                print_notifications && @info "\tNew block $blkfriend assigned";
                                nextBlockid = blkfriend[1];
                             end
                        end
                        nextBlock = BK[nextBlockid];
                    end

                    if isBlockFree(nextBlock, trainid, direction) # using Julia multiple dispatch
                        #updating current block
                        if currentBlock.id != ""
                            decreaseBlockOccupancy!(train, currentBlock, direction);
                        end

                        #updating next block, adding train
                        increaseBlockOccupancy!(train, nextBlock, direction);

                        # if trainid == "SB_29869"
                        #     println("$trainid $current_opid $kind $direction $line $duetime $t");
                        # end

                        # save_timetable && println(out_file,"$trainid,$current_opid,$kind,$direction,$line,$duetime,$t");
                        if(save_timetable || save_timetable_railml)
                            push!(df_timetable, (trainid,current_opid,kind,direction,line,duetime,t));
                        end

                        train.dyn.currentBlock = nextBlockid;

                        nextBlockDueTime = train.schedule[nop1].duetime - train.schedule[n_op].duetime;

                            # remove comment to list halting time at stations
                            # isStation(nextBlockid) && train.schedule[n_op+1].kind == "d" && println("$trainid,$nextBlockid,$nextBlockDueTime");

                            # nice way of listing blocks and travelling times by train
                            #println("#$(train.dyn.nextBlock),$(train.dyn.nextBlockDueTime),$trainid")

                        nextBlockRealTime = nextBlockDueTime
                        if use_buffering_time # 
                            # next block is a passenger station and is not supposed to get exo delay
                            if train.schedule[nop1].kind == "d" && !haskey(train.delay, nextBlockid)
                            # if we arrive at station inside buffering time, do not wait
                                if nextBlockDueTime > MAXIMUM_HALT_AT_STATION
                                    print_train_status && println("$trainid recovers $(nextBlockDueTime-MAXIMUM_HALT_AT_STATION)s in $nextopid");
                                    nextBlockRealTime = MAXIMUM_HALT_AT_STATION;
                                    #println("$trainid recovers in $nextopid");
                                end
                                if (nextBlockDueTime < MINIMUM_HALT_AT_STATION) && (n_op>1)
                                    nextBlockRealTime = MINIMUM_HALT_AT_STATION;
                                    print_train_status && println("$trainid has to wait at least $(MINIMUM_HALT_AT_STATION)s in $nextopid");
                                    #println("$trainid recovers in $nextopid");
                                end
                            end
                        end
                        delay_imposed = get(train.delay, naked_nextBlockid,0);

                        # here we will handle gains
                        # ....
                        
                        # if delay_imposed>0
                        #     println("##### $trainid,$nextBlockid,$delay_imposed");
                        # end

                        tt = t + nextBlockRealTime + delay_imposed;

                        print_train_status && delay_imposed > 0 &&
                            println("An exo-delay to train $trainid is imposed in  block [$nextBlockid]");

                        get!(Event, tt, Transit[]);
                        push!(Event[tt], train.schedule[nop1]);
                        t_final = max(tt, t_final); # cures the problem with the last train overnight
                    
                    else # block/station is full

                        if print_train_wait
                            if nextBlock.sblock.isempty 
                                println("Train $trainid needs to wait. Next block [$nextBlockid] is full [$(nextBlock.train)].");
                            else
                                print("Train $trainid needs to wait. "); 
                                print("Next superblock [$nextBlockid:$(nextBlock.sblock.id)] is full [$(nextBlock.sblock.trainid)]. ");
                                println("Time $t.");
                            end
                        end
                        # if trainid=="R_2217"
                        #     println("#1# $currentBlock");
                        #     println("#1# $nextBlock");
                        #     exit(1);
                        # end
                        # raise an error if the block is too small and we are looking to enlarge it
                        if catch_conflicts
                            throw(exception_blockConflict(trainid,nextBlockid,direction))
                        end

                        tt = t+TIME_TO_CHECK_FOR_FREE_BLOCK;
                        get!(Event, tt, Transit[])
                        push!(Event[tt], train.schedule[n_op])
                        train.dyn.n_opoints_visited -= 1
                        t_final = max(tt, t_final)


                    end

                #train ended his schedule
                else
                    if length(train.schedule) > 1 # yes, there are fossile trains with one entry only
                        print_train_end && (((t-duetime)> 0) && println("Train $trainid ended in $current_opid with a delay of $(t-duetime) seconds at unix time $t"))

                        #updating the values in the corresponding block, train ended
                        decreaseBlockOccupancy!(train, currentBlock, direction);
                        # save_timetable && println(out_file,"$trainid,$current_opid,$kind,$direction,$line,$duetime,$t");
                        if save_timetable || save_timetable_railml
                             push!(df_timetable, (trainid,current_opid,kind,direction,line,duetime,t));
                        end


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
            status = netStatus(RN,hashing=false);

            if (old_status == status) && (!isempty(status))

                print_flow && println("Simulation is stuck with times t_finals $t_final and $t_final_starting,
                                            t is $t ; status is  $status")

                #Event = nothing; #don't need to do that. it will be garbage collected.
                # resetSimulation(FL); # set trains dynamical variables to zero
                # resetDynblock(RN);
                @info "Simulation got stuck. Exiting.";
                return true;
            end
            t_evaluated=0
            old_status = status;
        end
        delete!(Event, t); # we finished all the tasks at time t and free up memory.
    end
    #Event = Dict{Int,Vector{Transit}}(); #don't need to do that. it will be garbage collected.
    # save_timetable && close(out_file)
    if save_timetable
        outfilenamecsv =  outfilename*".csv";
        CSV.write(outfilenamecsv, df_timetable);
        @info("The timetable generated by the simulation is printed on file \"$outfilename\"");
    end
    if save_timetable_railml 
        outfilenamerailml =  outfilename*".railml";
        outputRailML(outfilenamerailml, df_timetable);
    end

    print_flow && println("Simulation ended.")
    print_tot_delay && println("Total delay at the end of simulation is $totDelay")
    # resetSimulation(FL); # set trains dynamical variables to zero
    # resetDynblock(RN);
    return false
end
