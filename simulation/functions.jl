
"""
functions.jl : contains the definition of functions that are NOT needed for initializing our system on the infrastructure
"""

function dateToSeconds(d::String31)::Int
"""
Given a string in the format "yyyy-mm-dd HH:MM:SS"
returns the number of seconds elapsed from the epoch
"""
    dt::DateTime = Dates.DateTime(d, "dd.mm.yyyy HH:MM:SS")
    return Int(floor(datetime2unix(dt)))
    #return (Dates.hour(dt)*60+Dates.minute(dt))*60+Dates.second(dt)
end
function dateToSeconds(d::Int)::Int
"""
If the input is an Int do nothing
assuming that it is already the number of seconds elapsed from the epoch
"""
    return d
end

function runTest(RN::Network, FL::Fleet)
    """If test mode is enabled, runs test without printing simulation results on std out
    """

#    print("\nPerforming speed test with no output. Please be patient.\r")
    if Opt["test"] == 2
        print("Using @btime ...\r")
        @btime simulation($RN, $FL)
    # elseif Opt["TEST"] == 3
    #     @benchmark simulation($RN, $FL)
    else
        @time simulation(RN, FL)
        print("Macro @time was used.\n")
    end
end

function myRand(min::Float64, max::Float64)::Float64
    """ranged random number generator"""
    return rand(range(min,length=20,stop=max))
end

function netStatus(S::Set{String}, BK::Dict{String,Block}; hashing::Bool=false)

    """function that calculates the status of the simulation as a string of blocks
     and their occupancies in terms of train id;
     has also a hashing function to try to speed up
    """
    if isempty(S)
        println("in netstatus S is empty")
        return ""
    end

    status = "";
    for blk_id in sort(collect(keys(BK))) # we might need a sort here because the order of keys may change
        blk = BK[blk_id];
        if isa(blk.nt, Int)
            if blk.nt > 0
                status *= "$(blk_id):$(blk.train) ";
            end
        else
            status *= "$(blk_id):$(blk.train) ";

        end
    end

    #status *= "\n$S";

    #hashing && return sha256(status) |> bytes2hex; #sha256()->hexadecimal; bytes2hex(sha256())->string
    hashing && return hash(status);

    return status
end

function resetSimulation(FL::Fleet)#,RN::Network
"""
Resets the dynamical variables of trains in case of multiple simulation runs
"""
    #println("resetting Fleet")
    for trainid in keys(FL.train)
        FL.train[trainid].dyn = DynTrain(0,"","");
    end
end

#passing the valuea of RN to modify it before restarting the simulation in the try and catch, resetting blocks is mandatory, being that it doesn't exit before re-entering in simulation
function resetDynblock(RN::Network)#,
"""
Resets the dynamical variables of the blocks (trains running on them) in case of using the macro for the try-catch
"""
    #println("resetting Blocks")
    if Opt["multi_stations_flag"]

        directions=[-1,1]
        dir2trainscount=Dict{Int,Int}()
        for direction in directions
            dir2trainscount[direction]=0
        end

        for block in keys(RN.blocks)
            ntracks=RN.blocks[block].tracks

            if typeof(ntracks)==Int
                RN.blocks[block] = Block(block,ntracks,0,Set{String}())
            else

                # dir2trainscount=Dict{Int,Int}()
                #
                # for direction in directions
                #     dir2trainscount[direction]=0
                # end

                RN.blocks[block] = Block(block,ntracks,copy(dir2trainscount),Set{String}())

            end
        end
    else
        for block in keys(RN.blocks)
            ntracks=RN.blocks[block].tracks
            RN.blocks[block] = Block(block,ntracks,0,Set{String}())
        end
    end
end

function catch_conflict(RN,FL,parsed_args)

    DIRECTIONS=[-1,1];

    timetable_file = Opt["timetable_file"];
    while true
        try

            #one or multiple simulations
            if (parsed_args["multi_simulation"])
                # multiple_sim($(esc(RN)), $(esc(FL)))
                nothing;
            else
                one_sim(RN, FL)
            end

            break
        catch err

            if isa(err, KeyError) # if the error comes from non existing blocks:

                println("KeyError occurring : $(err.key)")
                name=err.key

                if Opt["multi_stations_flag"]
                    if isStation(name)

                        dir2platforms   = Dict{Int,Int}()
                        dir2trainscount = Dict{Int,Int}()

                        # create one platform per direction
                        for direction in DIRECTIONS
                            dir2platforms[direction]   = 1
                            dir2trainscount[direction] = 0
                        end

                        b = Block(
                                name,
                                # i,
                                dir2platforms,
                                dir2trainscount,
                                Set{String}()
                        )

                        RN.nb += 1

                        RN.blocks[name]=b

                        println("Added to RN.blocks the station block:",RN.blocks[err.key])
                    else
                        b = Block(
                                name,
                                # i,
                                1,
                                0,
                                Set{String}()
                        )

                        RN.nb += 1

                        RN.blocks[name]=b

                        println("Added to RN.blocks the normal block:",RN.blocks[err.key])
                    end

                else # no multiple tracks
                    b = Block(
                            name,
                            # i,
                            1,
                            0,
                            Set{String}()
                    )

                    RN.nb += 1

                    RN.blocks[name]=b

                    println("Added to RN.blocks the block:",RN.blocks[err.key])
                end

                resetSimulation(FL);
                resetDynblock(RN);

            else # if the error comes from try&catch:

                train=(err.trainid)
                block=err.block

                println("Before: ", RN.blocks[block])

                if Opt["multi_stations_flag"]
                    if isStation(block)

                        dir = err.direction
                        RN.blocks[block].tracks[dir] += 1

                        # for d in DIRECTIONS
                        #     RN.blocks[block].tracks[d] += 1
                        #     RN.blocks[block].nt[d] = 0
                        # end
                    else
                        RN.blocks[block].tracks += 1
                        RN.blocks[block].nt = 0
                        RN.blocks[block].train=Set{String}()
                    end
                else          # no multi-stations

                    RN.blocks[block].tracks += 1 #ntracks+1
                    RN.blocks[block].nt = 0
                    RN.blocks[block].train=Set{String}()
                end

                println("After:  ",RN.blocks[block])


                resetSimulation(FL);
                resetDynblock(RN);
            end



        end
    end

    #insert here function for saving the blocks list
    if occursin("-", timetable_file)
        _,date=split(timetable_file,"-")
        out_file_name="../data/simulation_data/blocks_catch-$date.csv"
    else
        out_file_name = "../data/simulation_data/blocks_catch.csv";
    end
    print_infra(RN,out_file_name)

end


#passing the valuea of RN to modify it before restarting the simulation in the try and catch, resetting blocks is mandatory, being that it doesn't exit before re-entering in simulation
function print_infra(RN::Network,out_file_name::String)#,
"""
printing blocks to file
"""
    open(out_file_name, "w") do OUT

        println(OUT, "id,tracks")

        block2track=Dict{String,Int}()

        for block in keys(RN.blocks)

            RN.blocks[block].id == "" && continue;

            ntracks=RN.blocks[block].tracks
            if typeof(ntracks) == Dict{Int,Int}
                n = sum(values(ntracks))
            else
                n = ntracks
            end

            block2track[block] = n
        end

        K = sort(collect(block2track), by= x-> x[2], rev=true)
        # println(OUT, K)
        for b in K
            println(OUT, b[1],",",b[2])
        end

    end
end


import Base.sort!
sort!(v::Vector{Transit}) = sort!(v, by=x->x.duetime) # usage: FL.train["SB29541"].schedule

import Base.issorted
issorted(v::Vector{Transit}) = issorted(v, by=x->x.duetime) # usage: FL.train["SB29541"].schedule


function check_nextblock_occupancy(train::Train,nt::Int,tracks_in_platform::Int)::Bool
    return (nt<tracks_in_platform)
end

#multiple dispatch functions for multiple-sided stations
function check_nextblock_occupancy(train::Train,nt::Dict{Int,Int},tracks_in_platform::Dict{Int,Int})::Bool

    track=train.track
    direction=train.direction

    #check occupancy in that direction
    return (nt[direction]<tracks_in_platform[direction])
end


#update next block if old simulation or new one updating a block, not station
function update_block(train::Train,next_nt::Int,
    nextBlock_train::Set{String},update::Int)::Tuple{Int, Set{String}}

    trainid=train.id
    next_nt+=update
    if update >0
        push!(nextBlock_train, trainid)
    else
        pop!(nextBlock_train, trainid)
    end
    return next_nt,nextBlock_train
end

#MULTIPLE DISPATCH
function update_block(train::Train,next_nt::Dict{Int,Int},
    nextBlock_train::Set{String},update::Int)::Tuple{Dict,Set{String}}

    trainid=train.id
    direction=train.direction

    next_nt[direction]+=update

    if update >0
        push!(nextBlock_train, trainid)
    else
        pop!(nextBlock_train, trainid)
    end

    return next_nt,nextBlock_train


end

function isStation(bst_name::String)
     a = split(bst_name, "-");
     return a[1] == a[2]
end
