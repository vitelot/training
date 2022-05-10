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

function initBlock(name::AbstractString, ntracks::Int)
    #list of the tracks, for now just 5
    tracks=[5]
    #two directions wrt a track
    DIRECTIONS=[-1,1];
    COMMON_DIRECTION = 0;

    if isStation(name)
        if (ntracks==1)
            # println("$bts has 1 platform,update to 2")
            printstyled("WARNING: station $name has only one platform.\n", bold=true)
            # ntracks+=1
        end

        if Opt["multi_stations_flag"] # directionality
            #number of directions taken into account
            n_dir = length(DIRECTIONS)

            #integer number of plats per direction
            n_plat = div(ntracks,n_dir)

            #remaining plat in common
            common = ntracks%n_dir

            dir2platforms   = Dict{Int,Int}()
            dir2trainscount = Dict{Int,Int}()

            #dictionaries for occupancy for every direction
            for direction in DIRECTIONS
                dir2platforms[direction]=n_plat
                dir2trainscount[direction]=0
            end

            #update of simulation: use also common plats.
            dir2platforms[COMMON_DIRECTION]=common

            b = Block(
                    name,
                    true,
                    dir2platforms,
                    dir2trainscount,
                    Set{String}()
            )


        else # station but directionality not required
            b = Block(
                    name,
                    true,
                    ntracks,
                    0,
                    Set{String}()
            )
        end
    else # directionality not required
        b = Block(
                name,
                false,
                ntracks,
                0,
                Set{String}()
        )
    end
    return b;
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
            if typeof(ntracks) == Int
                n = ntracks
            else
                n = sum(values(ntracks))
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

    DIRECTIONS = [-1,1]
    dir2trainscount = Dict{Int,Int}()

    for direction in DIRECTIONS
        dir2trainscount[direction] = 0
    end

    #println("resetting Blocks")
    for b in values(RN.blocks)
        ntracks=b.tracks

        if typeof(ntracks)==Int
            b.nt = 0;
        else
            b.nt = copy(dir2trainscount);
        end
        b.train = Set{String}();
    end

end

function catch_conflict(RN,FL,parsed_args)

    DIRECTIONS=[-1,1];

    timetable_file = Opt["timetable_file"];
    while true
        try
            one_sim(RN, FL)
            break
        catch err

            if isa(err, KeyError) # if the error comes from non existing blocks:

                println("KeyError occurring : $(err.key)")
                name=err.key

                if isStation(name)
                    b = initBlock(name,length(DIRECTIONS))
                else
                    b = initBlock(name,1)
                end

                RN.nb += 1
                RN.blocks[name]=b

                resetSimulation(FL);
                resetDynblock(RN);

            else # if the error comes from try&catch:

                train=(err.trainid)
                block=err.block
                b = RN.blocks[block];

                println("Tracks before at $block: ", b.tracks)

                if typeof(b.tracks)==Int
                    b.tracks += 1
                    # b.nt = 0
                else
                    dir = err.direction
                    b.tracks[dir] += 1
                end

                println("Tracks after at $block:  ",b.tracks)

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


function isStation(bst_name::AbstractString)
     a = split(bst_name, "-");
     return a[1] == a[2]
end
