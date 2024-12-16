# Determine the timetable based on the trains.csv file
using CSV, DataFrames, Dates;

@enum SpeedClass unknown slow normal fast

const ACCELERATIONTIME::Int = 30; # seconds
const DECELERATIONTIME::Int = 30; # seconds

function string2SpeedClass(s::String)::SpeedClass
    if s == "slow"
        return slow;
    elseif s=="normal"
        return normal;
    elseif s=="fast"
        return fast;
    else 
        return unknown;
    end
end

function approxTime(t::Int, delta::Int=30)::Int
    return t+ delta - t%delta;
end

function seconds2Time(t::Int)::String
    sec = t%60;
    min = (t÷60)%60;
    h = t÷3600;
    return lpad(string(h), 2, '0')*":"*lpad(string(min), 2, '0')*":"*lpad(string(sec), 2, '0');
end

struct Train
    name::String
    stops::Dict{String,Int}
    loco::String
    route::Vector{String}
    start_time::Int
    speedclass::SpeedClass
end

struct Block
    name::String
    length::Int
    direction::Int
    line::String
    speed::Vector{Int}
end

struct Station
    name::String
    length::Int
    maxspeed::Int
end

function main()
    # dir = "running/simdata/newexample/";
    # cd(dir);

    dbl = CSV.read("blocks.csv", comment="#", types=String, DataFrame);

    dtr = CSV.read("trains.csv", comment="#", types=String, DataFrame);

    dst = CSV.read("stations.csv", comment="#", DataFrame);

    T = Dict{String,Train}();

    for t in eachrow(dtr)
        name = join([t.type, t.number], "_");
        stops = split(t.stops, "-");
        stoptimes = parse.(Int,split(t.stop_times, "-"));
        Dstops = Dict(zip(stops,stoptimes));
        route = split(t.route,"-");
        loco = t.locoID;
        starttime = Dates.value(Time(t.starting_time)) ÷ 1000000000;
        speedclass = string2SpeedClass(t.speed_class);
        T[name] = Train(
            name,
            Dstops,
            loco,
            route,
            starttime,
            speedclass);
    end

    B = Dict{String,Block}();

    for b in eachrow(dbl)
        name=b.block;
        len = parse(Int,b.length);
        dir = parse(Int,b.direction);
        line = b.line;
        s = parse.(Int,split(b.speed,"-"));
        B[name] = Block(
            name,
            len,
            dir,
            line,
            s
        );
    end

    S = Dict{String,Station}();

    for s in eachrow(dst)
        S[s.id] = Station(s.id, s.length, s.maxspeed);
    end

    #train,bst,transittype,direction,line,distance,scheduledtime
    TimeTable = DataFrame(train=String[], bst=String[],
                transittype=String[],
                direction=Int[], line=String[], distance=Int[],
                scheduledtime=Int[]
    );

    for t in values(T)
        # println(t);
        firstblock = string(t.route[1], "-" , t.route[2]);
        direction = B[firstblock].direction;
        line = B[firstblock].line;
        distance = 0;
        time = t.start_time;
        speedclass = Int(t.speedclass);
        push!(TimeTable, (t.name, t.route[1], "b", direction, line, distance, time));
        time += ACCELERATIONTIME;
        for i in 2:length(t.route)-1
            r = t.route[i];
            blkname = string(t.route[i-1], "-" , r);
            blk = B[blkname];
            speed = blk.speed[speedclass] / 3.6; # m/s
            time += ceil(Int,blk.length / speed);
            time = approxTime(time);
            distance += blk.length;
            if r ∈ keys(S) # it's a station
                if r ∈ keys(t.stops) # train stops here. it's a station of course
                    time += DECELERATIONTIME;
                    push!(TimeTable, (t.name, r, "a", blk.direction, blk.line, distance, time));
                    time += t.stops[r];
                    push!(TimeTable, (t.name, r, "d", blk.direction, blk.line, distance, time));
                    time += ACCELERATIONTIME;
                else
                    push!(TimeTable, (t.name, r, "p", blk.direction, blk.line, distance, time));
                    time += ceil(Int,S[r].length / min(S[r].maxspeed/3.6, speed));
                    time = approxTime(time, 10);
                    push!(TimeTable, (t.name, r, "P", blk.direction, blk.line, distance, time));
                end
            else
                push!(TimeTable, (t.name, r, "p", blk.direction, blk.line, distance, time));

            end
        end
        r = t.route[end];
        blkname = string(t.route[end-1], "-" , t.route[end]);
        blk = B[blkname];
        speed = blk.speed[speedclass] / 3.6; # m/s
        time += ceil(Int, blk.length / speed);
        time = approxTime(time) + DECELERATIONTIME;
        distance += blk.length;
        push!(TimeTable, (t.name, t.route[end], "e", blk.direction, blk.line, distance, time));
    end
    TimeTable.daytime = seconds2Time.(TimeTable.scheduledtime);
    return TimeTable;
end

TimeTable = main();
CSV.write("timetable.csv", TimeTable);
