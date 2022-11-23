"""
    Block related functions
"""

COMMON_DIRECTION = 0; # index for the platforms used in both ways at stations

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

function initStation(r::DataFrameRow)
    # Stations are special blocks
    nrplatforms = r.ntracks;
    # we have the same number of platforms per direction
    # if we have an odd number of platforms, we reserve one for both directions
    n2 = div(nrplatforms,2);
    n0 = rem(nrplatforms,2); # remainder

    P = Dict(1 => n2, 2 => n2, 0 => n0);
    # initial occupations at zero
    NT = Dict(1 => 0, 2 => 0, 0 => 0);

    s = Station(
            r.id,
            P,
            NT,
            Set{String}(),
            r.nsidings
    );
    return s;
end


function initBlock(r::DataFrameRow)
    # r is a row of the block df containing: block,line,length,direction,ismono

    line = r.line;
    # now a block is determined by its line too
    name = string(r.block, "-", line); 
    dir = r.direction;
    ismono = r.ismono;
    # the number of tracks is always 1 since we specify the line number; only in stations we may have many tracks;
    # one trach may be used both ways if ismono==true
    ntracks = 1;

    b = Block(
            name,
            line,
            r.length,
            dir,
            r.ismono,
            ntracks,
            0,
            Set{String}()
        );

    return b;


    ######### old code follows ##########
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

        if !Opt["free_platforms"] # directionality
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

function isBlockFree(station::Station, direction::Int)::Bool
    # the direction is found in the blocks, but not for stations, so we need to pass it in the arguments
    

    return (
        (station.nt[direction] < station.platforms[direction]) # there is at least one platform available
                    || 
        (station.nt[COMMON_DIRECTION] < station.platforms[COMMON_DIRECTION]) # there is at least one platform with a common direction, and there is free space
    );
end

function isBlockFree(blk::Block, direction::Int)::Bool

    return blk.nt < blk.tracks;

end

function decreaseBlockOccupancy!(train::Train, station::Station, direction::Int)

    pop!(station.train, train.id);

    # if the common track is occupied, free it at first
    if station.nt[COMMON_DIRECTION] > 0
        station.nt[COMMON_DIRECTION] -= 1;
    else
        station.nt[direction] -= 1;
    end

    return;
end

function decreaseBlockOccupancy!(train::Train, blk::Block, direction::Int)

    pop!(blk.train, train.id);

    blk.nt -= 1;

    return;
end

function increaseBlockOccupancy!(train::Train, station::Station, direction::Int)

    push!(station.train, train.id);
    
    # if the tracks dedicated to the direction are free, occupy one at first
    if station.nt[direction] < station.platforms[direction]
        station.nt[direction] += 1;
    
        # if nothing else is free, occupy the common track
    elseif station.nt[COMMON_DIRECTION] < station.platforms[COMMON_DIRECTION]
        station.nt[COMMON_DIRECTION] += 1;
    
    else    
        @warn "We cannot increase the occupancy of station $(station.id).";
    end

 return;

end

function increaseBlockOccupancy!(train::Train, blk::Block, direction::Int)
    # COMMON_DIRECTION = 0;

    push!(blk.train, train.id)
    blk.nt += 1;

    # if the tracks dedicated to the direction are free, occupy one at first
    # direction = train.direction;
    # nr_trains = blk.nt;
    # if nr_trains[direction] < blk.tracks[direction]
    #     nr_trains[train.direction] += update;
    #     return;
    # end

    # # if nothing else is free, occupy the common track
    # if get(blk.tracks, COMMON_DIRECTION, 0) > 0
    #     nr_trains[COMMON_DIRECTION] = get(nr_trains, COMMON_DIRECTION, 0) + update
    #     return;
    # end

    # it has never to come until here, otherwise something is wrong
    # @warn "We cannot increase the occupancy of block $(blk.id)."
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

    DIRECTIONS = [-1,0,1]
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
#@show get(RN.blocks, "WBFS12-WBFS22", Block())
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

                println("New block found : $(err.key)")
                name=err.key

                if isStation(name)
                    b = initBlock(name,length(DIRECTIONS))
                else
                    b = initBlock(name,1)
                end

                RN.nb += 1
                RN.blocks[name]=b
#@show RN.nb
                resetSimulation(FL);
                resetDynblock(RN);

            else # if the error comes from try&catch:

                train=(err.trainid)
                block=err.block
                b = RN.blocks[block];

                println("Nr of tracks before at $block: ", b.tracks)

                if typeof(b.tracks)==Int
                    b.tracks += 1
                    # b.nt = 0
                else
                    dir = err.direction
                    b.tracks[dir] += 1
                end

                println("Nr of tracks after  at $block: ",b.tracks)

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
