"""
    Block related functions
"""

COMMON_DIRECTION = 0; # index for the platforms used in both ways at stations

function initStations(df::DataFrame, RN::Network)::Nothing

    for r in eachrow(df)
        # Stations are special blocks
        nrplatforms = r.ntracks;
        # we have the same number of platforms per direction
        # if we have an odd number of platforms, we reserve one for both directions
        n2 = div(nrplatforms,2);
        n0 = rem(nrplatforms,2); # remainder

        P = Dict(1 => n2, 2 => n2, 0 => n0);
        # initial occupations at zero
        # NT = Dict(1 => 0, 2 => 0, 0 => 0);
        NT = Dict(1 => Set{String}(), 2 => Set{String}(), 0 => Set{String}());

        sblockid = r.superblock;
        get!(RN.superblocks, sblockid, SuperBlock(sblockid));

        s = Station(
                r.id,
                P,
                r.nsidings,
                NT,
                RN.superblocks[sblockid] # use a distinct id for each block/station for the moment
                # Set{String}()
        );

        RN.stations[s.id] = s; 
        RN.ns += 1;
    end

    return;
end


function initBlocks(df::DataFrame, RN::Network)::Nothing

    # print_flow              = Opt["print_flow"];

    # superblockidbase = 1270; # to assign to superblocks with index 0 and ismono==1

    for r in eachrow(df)

        # r is a row of the block df containing: block,line,length,direction,tracks,ismono,superblock
        # now a block is determined by its line too
        name = string(r.block, "-", r.line); 
        
        sblockid = r.superblock;
       
        # i'm afraid we need to set superblocks by hand in the configuration setup
        # and the ismono flag is unused!
        # if r.ismono==1 && sblockid<=0
        #     sameblock = join(reverse(split(r.block,"-")),"-"); # this is the same block in reverse order since ismono==1
        #     sameblockname = string(sameblock,"-", r.line); # we assume it's on the same line
        #     if haskey(RN.blocks, sameblockname) # we already found this block and already assigned a superblock id
        #         sblockid = RN.blocks[sameblockname].sblock.id;
        #         print_flow && println("Assigned same superblock $sblockid of block $sameblockname to block $name");
        #     else
        #         sblockid = superblockidbase;
        #         print_flow && println("Assigned superblock $sblockid to block $name");
        #         superblockidbase += 1;
        #     end
        # end

        get!(RN.superblocks, sblockid, SuperBlock(sblockid));
        
        # the number of tracks is always 1 since we specify the line number; 
        # unless ricalculated with try and catch;
        # only in stations we may have many tracks;
        # one track may be used both ways if ismono==true
        
        b = Block(
            name,
            string(r.line),
            r.length,
            r.direction,
            r.ismono,
            r.tracks,
            0,
            Set{String}(),
            RN.superblocks[sblockid] # use a distinct id for each block for the moment
            );

        RN.blocks[name] = b; 
        RN.nb += 1;
    end
    return;
end

function isBlockFree(station::Station, trainid::String, direction::Int)::Bool
    # the direction is found in the blocks, but not for stations, so we need to pass it in the arguments

    if station.sblock.id <= 0 # if the superblock coincides with the block itself
        # there is at least one platform available
        if length(station.train[direction]) < station.platforms[direction]
            return true;
        end

        # there is at least one platform with a common direction available
        if length(station.train[COMMON_DIRECTION]) < station.platforms[COMMON_DIRECTION]
            return true;
        end

        return false;
    else
        if station.sblock.isempty
            return true;
        else
            if station.sblock.trainid == trainid
                return true;
            else
                return false;
            end
        end
    end
end

function isBlockFree(blk::Block, trainid::String, direction::Int)::Bool
    if blk.sblock.id <= 0
        return blk.nt < blk.tracks;
    else
        if blk.sblock.isempty
            return true;
        else
            if blk.sblock.trainid == trainid
                return true;
            else
                return false;
            end
        end
    end
end

function decreaseBlockOccupancy!(train::Train, station::Station, direction::Int)::Nothing

    # if station.id == "REN"
            
    #     println("#2# #####");
    #     println("#2# train: $(train.id) --- direction $direction");
    #     println("#2# $station");
    #     println("#2# #####");
    # end

    if station.sblock.id > 0 # this station is part of a one track superblock
        station.sblock.isempty = true;
        station.sblock.trainid = "";
        return;
    end

    for S in values(station.train) # dictionary with set of trains in each direction
        if train.id ∈ S
            pop!(S, train.id);
            return;
        end
    end

    @warn "Cannot remove train $(train.id) from station $(station.id)";

    return;
end

function decreaseBlockOccupancy!(train::Train, blk::Block, direction::Int)::Nothing

    if blk.sblock.id > 0
        blk.sblock.isempty = true;
        blk.sblock.trainid = "";
        return;
    end

    pop!(blk.train, train.id);

    blk.nt -= 1;

    return;
end

"""
    increaseBlockOccupancy!(train::Train, station::Station, direction::String)

Increases the occupancy of a station track when a train moves into it.

- Updates the station track's occupancy status and assigns the train to it.

# Arguments
- `train::Train`: The train moving into the block.
- `station::Station`: The station being occupied.
- `direction::String`: The direction of the train.
"""
function increaseBlockOccupancy!(train::Train, station::Station, direction::Int)::Nothing
    if station.sblock.id > 0 # this station is part of a one track superblock
        station.sblock.isempty = false;
        station.sblock.trainid = train.id;
        return;
    end
    
    # if the tracks dedicated to the direction are free, occupy one at first
    if length(station.train[direction]) < station.platforms[direction]
        push!(station.train[direction], train.id);
        
        # if nothing else is free, occupy the common track
    elseif length(station.train[COMMON_DIRECTION]) < station.platforms[COMMON_DIRECTION]
        push!(station.train[COMMON_DIRECTION], train.id);
    
    else    
        @warn "We cannot increase the occupancy of station $(station.id).";
    end

 return;

end

"""
    increaseBlockOccupancy!(train::Train, block::Block, direction::String)

Increases the occupancy of a block when a train moves into it.

- Updates the block's occupancy status and assigns the train to it.

# Arguments
- `train::Train`: The train moving into the block.
- `block::Block`: The block being occupied.
- `direction::Int`: The direction of the train.

"""
function increaseBlockOccupancy!(train::Train, blk::Block, direction::Int)::Nothing
    # COMMON_DIRECTION = 0;

    if blk.sblock.id > 0 # this block is part of a one track superblock
        blk.sblock.isempty = false;
        blk.sblock.trainid = train.id;
        return;
    end

    push!(blk.train, train.id)
    blk.nt += 1;

    return;
end

"""
printing blocks to file
"""
function print_infra(RN::Network, out_block_file_name::String, out_station_file_name::String)

    
    open(out_block_file_name, "w") do OUT

        println(OUT, "block,line,length,direction,tracks,ismono");

        for blockName in sort(collect(keys(RN.blocks)))

            blk = RN.blocks[blockName];

            # skip the empty block
            blk.id == "" && continue;

            (op1, op2, line) = split(blockName, "-");
            
            blk = string(op1,"-",op2);
            dir = blk.direction;
            length = blk.length;
            ntracks = blk.tracks;
            ismono = blk.ismono;

            println(OUT, "$blk,$line,$length,$dir,$ntracks,$ismono");

        end
    end

    open(out_station_file_name, "w") do OUT
        println(OUT, "id,ntracks,nsidings");
        for stationName in sort(collect(keys(RN.stations)))

            s = RN.stations[stationName];

            # skip the empty station
            s.id == "" && continue;

            ntracks = sum(values(s.platforms));
            nsidings = s.sidings;
            println(OUT, "$stationName,$ntracks,$nsidings");
        end
    end
end

"""
Resets the dynamical variables of the blocks (trains running on them) in case of using the macro for the try-catch
"""
function resetDynblock(RN::Network)
    # passing the valuea of RN to modify it before restarting the simulation in the try and catch, 
    # resetting blocks is mandatory, being that it doesn't exit before re-entering in simulation
    print_flow::Bool = Opt["print_flow"];

    print_flow && @info "Resetting the occupation of blocks in order to restart.";

    for b in values(RN.blocks)
        b.nt = 0;
        b.train = Set{String}();
    end
    for s in values(RN.stations)
        s.train = Dict(1=>Set{String}(), 2=>Set{String}(), 0=>Set{String}());
    end

end

function isStation(bst_name::AbstractString)
    a = split(bst_name, "-");
    return a[1] == a[2];
end

"""
    catch_conflict(RN, FL::Fleet, parsed_args)

Detect and resolve conflicts arising from insufficient block capacity in the railway network simulation.

# Arguments
- `RN`: Railway network configuration or structure.
- `FL::Fleet`: The fleet of trains participating in the simulation.
- `parsed_args`: Parsed arguments containing configuration options.

# Description
The `catch_conflict` function runs the `one_sim(RN, FL)` simulation to identify blocks where conflicts occur, such as multiple trains occupying the same block. If a conflict arises:
- A `KeyError` is triggered, indicating a missing or insufficiently defined block.
- If the block is identified as a station, the user is warned to update the station data in `../configuration/data/extra-stations.csv`.
- For generic blocks, a warning prompts the user to update the block definitions in `../simulation/data/blocks.csv` to increase track capacity or define missing blocks.

The function continues running the simulation iteratively until no more conflicts are detected, allowing the railway network to adapt dynamically by updating block capacities as needed.
"""
function catch_conflict(RN::Network, FL::Fleet,parsed_args)

    timetable_file = Opt["timetable_file"];

    while true
        try
            one_sim(RN, FL);
            break;
        catch err

            if isa(err, KeyError) # if the error comes from non existing blocks:

                println("New block found : $(err.key)")
                name=err.key

                if isStation(name)
                    # b = initBlock(name,length(DIRECTIONS))
                    s = split(name, "-")[1];
                    @warn "Station $s not found. Please add its info in ../configuration/data/extra-stations.csv";
                else
                    @warn "Block $name not found. Please add its info in ../simulation/data/blocks.csv";
                    # b = initBlock(name,1)
                end

                # RN.nb += 1
                # RN.blocks[name]=b
                # #@show RN.nb
                # resetSimulation(FL);
                # resetDynblock(RN);
                @warn "\tExiting.";
                exit(1);

            else # if the error comes from try&catch:

                # b::Block;
                # s::Station;

                train = (err.trainid)
                blockName = err.block
                dir = err.direction;

                if occursin("-", blockName) # it's a block
                    b = RN.blocks[blockName];
                    println("Nr of tracks before at $blockName: ", b.tracks);
                    b.tracks += 1;
                    println("Nr of tracks after  at $blockName: ", b.tracks)
                else # it's a station
                    s = RN.stations[blockName];
                    println("Nr of platforms before at $blockName: ", s.platforms);
                    s.platforms[dir] += 1;
                    println("Nr of platforms after  at $blockName: ", s.platforms);
                end

                resetSimulation(FL);
                resetDynblock(RN);
            end
        end
    end

    #insert here function for saving the blocks list
    if occursin("-", timetable_file)
        _,date=split(timetable_file,"-")
        out_block_file_name="../simulation/data/blocks_catch-$date.csv"
        out_station_file_name="../simulation/data/stations_catch-$date.csv"
    else
        out_block_file_name = "../simulation/data/blocks_catch.csv";
        out_station_file_name = "../simulation/data/stations_catch.csv";
    end
    print_infra(RN, out_block_file_name, out_station_file_name);
    
end


