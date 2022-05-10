"""
    Block related functions
"""

########################################
##EXCEPTIONS DEFINING
##################################
struct exception_blockConflict <: Exception
        trainid::String
        block::String
        direction::Int
    end

Base.showerror(io::IO, e::exception_blockConflict) =
    print(io, "Train $(e.trainid) has conflict in block $(e.block) ");

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


function isStation(bst_name::String)
     a = split(bst_name, "-");
     return a[1] == a[2]
end
