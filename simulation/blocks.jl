"""
    Block related functions
"""

COMMON_DIRECTION = 0; # index for the platforms used in both ways at stations

function initStation(r::DataFrameRow)
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

    s = Station(
            r.id,
            P,
            r.nsidings,
            NT,
            10000+rownumber(r) # use a distinct id for each block/station for the moment
            # Set{String}()
    );
    return s;
end


function initBlock(r::DataFrameRow)
    # r is a row of the block df containing: block,line,length,direction,tracks,ismono
    # now a block is determined by its line too
    name = string(r.block, "-", r.line); 
    
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
        rownumber(r) # use a distinct id for each block for the moment
        );
        
    return b;
end

function isBlockFree(station::Station, direction::Int)::Bool
    # the direction is found in the blocks, but not for stations, so we need to pass it in the arguments

    # there is at least one platform available
    if length(station.train[direction]) < station.platforms[direction]
        return true;
    end

    # there is at least one platform with a common direction available
    if length(station.train[COMMON_DIRECTION]) < station.platforms[COMMON_DIRECTION]
        return true;
    end

    return false;
end

function isBlockFree(blk::Block, direction::Int)::Bool

    return blk.nt < blk.tracks;

end

function decreaseBlockOccupancy!(train::Train, station::Station, direction::Int)

    # if station.id == "REN"
            
    #     println("#2# #####");
    #     println("#2# train: $(train.id) --- direction $direction");
    #     println("#2# $station");
    #     println("#2# #####");
    # end

    for S in values(station.train) # dictionary with set of trains in each direction
        if train.id ∈ S
            pop!(S, train.id);
            return;
        end
    end

    @warn "Cannot remove train $(train.id) from station $(station.id)";

    return;
end

function decreaseBlockOccupancy!(train::Train, blk::Block, direction::Int)

    pop!(blk.train, train.id);

    blk.nt -= 1;

    return;
end

function increaseBlockOccupancy!(train::Train, station::Station, direction::Int)

    
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

function increaseBlockOccupancy!(train::Train, blk::Block, direction::Int)
    # COMMON_DIRECTION = 0;

    push!(blk.train, train.id)
    blk.nt += 1;

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

function catch_conflict(RN,FL,parsed_args)

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


function isStation(bst_name::AbstractString)
     a = split(bst_name, "-");
     return a[1] == a[2];
end
