"""
compose.jl

Input: 
        1) a csv file with the daily PAD Zuglaufdaten as provided by OeBB
        2) a csv file with the preprocessed xml containing the yearly scheduled timetable 
        3) a csv file with the blocks found from the RINF data: "rinf-blocks.csv"
        4) a csv file with the operational points determined from RINF: "rinf-OperationalPoints.csv"
                        outfile = "blocks.csv"
Output:
        1) a csv file with the timetable to use in the simulation: "timetable.csv"
        2) a csv file with the list of blocks for the simulation: "blocks.csv"
        3) a csv file with the list of operational points with more than one track (stations, junctions)
        - an intermediate file "blocks-xml-YEAR.csv" distilled from RINF and XML

Description:
        The task of this script is to cure the many issues present in data.
        
        First, very often some trains do not appear in the official schedule.
        Usually these are international trains that exit Austria and for some reason
        reenter somewhere else. In this case no information is available on the line they will
        travel on and the direction. This script assigns both direction and line to those trains.
        
        Second, some trains disappear in one station and reappear far away. This script
        builds the network of operational points and uses it to infer where the disappearing 
        trains would have passed through. The teansit times at the added locations are estimated
        with a linear interpolation. If more than POPPING_JUMPS are necessary, the train is
        removed from the network and popped directly into its new location.
"""

@info "Loading libraries";

using CSV, DataFrames;
include("MyGraphs.jl");
include("MyDates.jl");
using .MyGraphs, .MyDates;
include("parser.jl");

import Base.pop!;
function pop!(df::AbstractDataFrame)::NamedTuple
        r=copy(df[nrow(df),:]); 
        deleteat!(df, nrow(df)); 
        return r;
end

pl = println;

@info "We are going to build the timetable for the simulation.\n\
        \tSince we have lots of trains in Austria and during the day some data are not retrieved,\n\
        \twe need to repair the schedule and this takes some time. Please relax.\n";

UInt = Union{Int,Missing};
UString = Union{String,Missing};

const DEBUG = 1; # five levels of debugging

const ACCEPTED_TRAJ_CODE        = ["Z","E"];
const POPPING_JUMPS = 10; # number of jumps allowed to fill in timetable holes
const FAST_STATION_TRANSIT_TIME = 10;  # time in sec that a train is supposed to need to go through a station while transiting
const STATION_LENGTH = 200; # average length of stations in meters; used to estimate passing time

# list of stations not found in the rinf data
EXTRA_STATION_FILE = "./data/extra-stations.csv";

#CLI parser
parsed_args = parse_commandline()

date          = parsed_args["date"] # default = "09.05.18"
in_file       = parsed_args["file"]
source_path   = parsed_args["source_data_path"]
target_path   = parsed_args["target_data_path"]
# nr_exo_delays = parsed_args["exo_delays"];
use_real_time = parsed_args["use_real_time"];
find_rotations= parsed_args["rotations"];
xml_schedule  = parsed_args["xml_schedule"];

@enum TrackNr TWOTRACKS=0 ONETRACK=1 UNASSIGNED=-1; # kind of block (monorail, doublerail)

struct Block
        name::String
        line::Vector{String}
        length::Vector{Int}
        direction::Int
end

"""
    translateGerman(s::AbstractString)::String

TBW
"""
function translateGerman(s::AbstractString)::String
        D = Dict( "Beginn" => "b", #"begin",
                  "Durchfahrt" => "p", #"pass",
                  "Ankunft" => "a", #"arrival",
                  "Abfahrt" => "d", #"departure",
                  "Ende" => "e" #"end"
                );
        return D[s];
end


"""
    loadPAD(file::String)::DataFrame

TBW
"""
function loadPAD(file::String)::DataFrame
        @info "Loading the PAD file \"$file\" "

        bigpad = CSV.File(file,
        header =
        [:day,
        :typecode,
        :traintype, :trainnr,
        :bst, :bstname,
        :runningtype,
        :transittype,
        :scheduledtime, :realtime,
        :delay,
        :loco1, :loco2, :loco3, :loco4, :loco5],
        skipto = 2) |> DataFrame;
        
        dropmissing!(bigpad, :scheduledtime);
        filter!(x->length(x.scheduledtime)>0, bigpad );

        # keep only running trains Z=scheduled, E=substitution
        filter!(x->x.runningtype ∈ ACCEPTED_TRAJ_CODE, bigpad);
        
        # remove OP at the border
        filter!(x->!startswith(x.bstname,"Staatsgrenze"), bigpad);
        
        select!(bigpad,
        [:traintype, :trainnr] => ByRow((x,y)->string(x,"_",y)) => :train,
        :bst => ByRow(x->replace(x,r"[ _]+"=>"")) => :bst,
        :transittype => ByRow(x->translateGerman(x)) => :transittype,
        :scheduledtime => ByRow(x->dateToSeconds(x)) => :scheduledtime
        );
        
        sort(bigpad, [:train, :scheduledtime]);
end

"""
    loadXML(file::String)::DataFrame

TBW
"""
function loadXML(file::String)::DataFrame
        @info "Loading the preprocessed XML file \"$file\" "
        xml = CSV.File(file) |> DataFrame;
        # cleaning done already by scanxml.jl
        # dropmissing!(xml, :bst);
        # # unique!(xml);
        # filter!(x->!startswith(x.bst,"KM "), xml);
        # filter!(x->!occursin(r"^I\d+$", x.bst), xml);
        # transform!(xml, :bst => ByRow(x->replace(x, r"[ _]+" => "")) => :bst);
        # # remove OP at the border
        # filter!(x->!startswith(x.bstname,"Staatsgrenze"), xml);

        return(xml);
end

function loadBLK(blkfile::String)
        @info "Loading the information on blocks from file \"$blkfile\" "

        DataFrame(CSV.File(blkfile))
end


"""
    cleanBstPADXML!(dfpad::DataFrame, dfxml::DataFrame)

Remove lines in both dataframes that contain :bst that are not present in both.
"""
function cleanBstPADXML!(dfpad::DataFrame, dfxml::DataFrame)
        @info "Removing the operational points that do not appear in both PAD and XML datasets"

        bstpad = unique(select(dfpad, :bst));
        bstxlm = unique(select(dfxml, :bst));
        
        aj = antijoin(bstpad,bstxlm, on=:bst);
        filter!(x->(x.bst ∉ aj.bst), dfpad);
        
        if !xml_schedule 
                aj = antijoin(bstxlm,bstpad, on=:bst);
                filter!(x->(x.bst ∉ aj.bst), dfxml);
        end

        nothing
end

function findBlocks(df::DataFrame, outfile="")::DataFrame
        
        @info "Finding blocks by aggregating two consecutive lines";

        # cleaning already done in scanxml.jl

        gd = groupby(df, :train);
        df = nothing;

        D = DataFrame(block=String[], line=String[], length=Int[], direction=Int[]);

        for df_train in gd
                train = df_train.train[1];

                sort!(df_train, :distance);
                for n = 2:nrow(df_train)
                        b1 = df_train.bst[n-1]; b2 = df_train.bst[n];
                        lenm = df_train.distance[n] - df_train.distance[n-1]; # blk length in meters
                        sec = df_train.line[n-1];
                        dir = df_train.direction[n-1];
                        ismissing(sec) && (sec=df_train.line[n-2]; );
                        ismissing(dir) && (dir=df_train.direction[n-2];);
                        blk = string(b1,"-",b2);
                        blk = replace(blk, r" +" => "");
                        push!(D, (blk,sec,lenm,dir));
                        #BlkList[blk] = get(BlkList,blk,0) + 1;
                end
        end

        unique!(D);

        if outfile !== "" 
                @info "Saving blocks on file \"$outfile\"";
                CSV.write(outfile, sort(D,:block));
        end

        D
end

"""
    trainMatchXML(dfpad::DataFrame, dfxml::DataFrame)::DataFrame

Uses the XML file to build a timetable with the trains travelling in a specific day.
We collect those trains from the PAD file.
Missing time is interpolated based on the travelled distance.
Only the missing times at the start and end of the travel are fetched from PAD.
We do not fetch all missing times from PAD since the scheduled time in PAD may 
change a bit wrt the scheduled time in XML.
"""
function trainMatchXML(dfpad::DataFrame, dfxml::DataFrame, dfblk::DataFrame)::DataFrame
        @info "Building a timetable from the XML schedule";
        gdxml = groupby(dfxml, :train);
        gdpad = groupby(dfpad, :train);
 
        # based on the scheduled PAD data, we build a dictionary with
        # key = train-bst and value with the scheduled time at that bst; to be used to fill the voids in the xml. 
        Dpad = Dict{String, Int}();
        for gd in gdpad
                train = gd.train[1];

                for r in eachrow(gd)
                        key = string(train, "-", r.bst,"-", r.transittype);
                        Dpad[key] = r.scheduledtime;
                end
        end
         
        # these are the trains we shall consider
        padtrainlist = unique(dfpad.train);
        xmltrainlist = unique(dfxml.train);

        # select all trains in pad that are in xml
        trainlist = filter(x-> x ∈ xmltrainlist, padtrainlist);
        
        # this will be our processed schedule
        dfout = DataFrame(train =UString[], bst=UString[], transittype=UString[],
                direction=UInt[],
                line=UString[], distance=UInt[],
                scheduledtime=UInt[]
                );

        # add 20xx to the year format
        datef = replace(date, r"\.(\d\d)$" => s".20\1");
        
        # we cycle through all trains
        for train in trainlist
                gd = gdxml[(train=train,)];

                # scan the schedule
                for r in eachrow(gd)
                        bst = r.bst;
                        direction = r.direction;
                        cumuldist = r.distance;
                        line = r.line;
                        if ismissing(r.arrival)
                                arrival = 0;
                        else
                                arrival = dateToSeconds("$datef $(r.arrival)");
                        end
                        if ismissing(r.departure)
                                departure = 0;
                        else
                                departure = dateToSeconds("$datef $(r.departure)");
                        end

                        if r.type == "pass"
                                # one of the two can be non zero. We cure the remaining zeros later.
                                scheduledtime = max(arrival,departure);
                                # only the first and last missing valued are taken from PAD
                                rn = rownumber(r); # gives the index of r in gd
                                if scheduledtime == 0 && (rn==1 || rn==length(gd.bst))
                                        key = string(train,"-",bst,"-p");
                                        scheduledtime = get(Dpad, key, 0);
                                end
                                push!(dfout, (train, bst, "p", direction, line, cumuldist, scheduledtime));
                        elseif r.type == "stop"
                                # when a stop is reported but only one time is available
                                # assume 30 sec of stopping time
                                if arrival==0 && departure>0
                                        arrival = departure-30;
                                end
                                if arrival>0 && departure==0
                                        departure = arrival+30;
                                end
                                push!(dfout, (train, bst, "a", direction, line, cumuldist, arrival));
                                push!(dfout, (train, bst, "d", direction, line, cumuldist, departure));
                        elseif r.type == "begin"
                                scheduledtime = max(arrival,departure);
                                if scheduledtime == 0 
                                        key = string(train,"-",bst,"-b");
                                        scheduledtime = get(Dpad, key, 0);
                                end
                                push!(dfout, (train, bst, "b", direction, line, cumuldist, scheduledtime));
                        elseif r.type=="end"
                                scheduledtime = max(arrival,departure);
                                if scheduledtime == 0 
                                        key = string(train,"-",bst,"-e");
                                        scheduledtime = get(Dpad, key, 0);
                                end
                                push!(dfout, (train, bst, "e", direction, line, cumuldist, scheduledtime));
                        else
                                @warn "Transit type $(r.type) not recognised"
                        end

                        # push!(dfout, (train, bst, transittype, direction, line, cumuldist, scheduledtime));
                end
  
        end
        
        # now we fix the remaining zeros in the scheduled time
        gdxml = groupby(dfout, :train);

        # The remaining time gaps are just a few, so we decide to delete them.
        # Julia does not allow the deletion from a subdataframe
        # so we fill a array and will delete at the end in another sweep.
        ToDelete = String[];
        for gd in gdxml
                nrowgd = nrow(gd);
                train = gd.train[1];

                # index of the first non zero scheduled time
                f = findfirst(x->x>0, gd.scheduledtime);
                for i = 1:f-1
                        push!(ToDelete, string(train,"-",gd.bst[i]));
                end
                f = findlast(x->x>0, gd.scheduledtime);
                for i = f+1:length(gd.scheduledtime)
                        push!(ToDelete, string(train,"-",gd.bst[i]));
                end

                for i in 1:nrowgd

                        t = gd[i, :scheduledtime];
                        d = gd[i, :distance];


                        if t == 0
                                if i == 1
                                        println("First point has still zero time: $(gd[i,:train]),$(gd[i,:bst])");
                                        continue;
                                end
                                # get info from previous time and distance
                                t0 = gd[i-1, :scheduledtime];
                                d0 = gd[i-1, :distance];
                                
                                i1 = i+1
                                if i1 > nrowgd
                                        println("Last point has still zero time: $(gd[i,:train]),$(gd[i,:bst])");
                                        continue;
                                end
                                # find next non zero time
                                for j = i+1 : nrowgd
                                        if gd[j,:scheduledtime] > 0
                                                i1 = j;
                                                break;
                                        end
                                end
                                t1 = gd[i1, :scheduledtime];
                                # in the XML there is no day, so the time can refer to the next day
                                # we detect these anomalies and correct here:
                                # If the previous time is larger than the following one, we had a day crossing.
                                if t0>t1+10000 # next day
                                        t1 += 86400;
                                end
                                d1 = gd[i1, :distance];
                                # linear regression
                                t = floor(Int, t0 + (t1-t0)/(d1-d0)*(d-d0));
                                
                                gd[i, :scheduledtime] = t;
                        end
                        # curing missing direction and line:
                        # we assume that they are the same of previous bst
                        if ismissing(gd[i, :direction])
                                gd[i,:direction] = gd[i-1, :direction];
                        end
                        if ismissing(gd[i, :line])
                                gd[i,:line] = gd[i-1, :line];
                        end                    
                end
        end
        length(ToDelete) > 0 && println("Deleting $ToDelete since their initial and final scheduled time cannot be inferred");
        filter!(x-> string(x.train,"-",x.bst) ∉ ToDelete, dfout);
        
        gdxml = groupby(dfout, :train);
        for gd in gdxml
                for i = 2:nrow(gd)
                        # last correction for the day jump
                        if gd.scheduledtime[i-1] - gd.scheduledtime[i] > 10000
                                gd.scheduledtime[i] += 86400;
                        end
                end
        end

        dfout
end


"""
    trainMatch(dfpad::DataFrame, dfxml::DataFrame)::DataFrame

TBW
"""
function trainMatch(dfpad::DataFrame, dfxml::DataFrame, dfblk::DataFrame)::DataFrame
        @info "Building a clean timetable";
        gdpad = groupby(dfpad, :train);
        gdxml = groupby(dfxml, :train);
        
        G = loadGraph(copy(dfblk), type="directed");
        
        BlkList = Dict{String, Block}();
        for r in eachrow(dfblk)
                (name, line, distance, direction) = r[:];
                get!(BlkList, name, Block(name, String[], Int[], direction));
                push!(BlkList[name].line, line); 
                push!(BlkList[name].length, distance);
        end
        
        # based on the scheduled xml data, we build a dictionary with
        # key = train-bst and value with the info at that bst 
        Dxml = Dict{String, DataFrameRow}();
        for gd in gdxml
                train = gd.train[1];

                for r in eachrow(gd)
                        key = string(train, "-", r.bst);
                        Dxml[key] = r[[:direction, :line, :distance]];
                end
        end
        
        # this will be our processed schedule
        dfout = DataFrame(train =UString[], bst=UString[], transittype=UString[],
                direction=UInt[],
                line=UString[], distance=UInt[],
                scheduledtime=UInt[]
                );
        
        # we cycle through all trains
        for gd in gdpad
                nrowgd = nrow(gd);
                nrowgd>1 || continue; # remove one line trains

                train = gd.train[1];
                poppy = ""; ispopping=false;
                cumuldist = distance = 0; iscumul = false;

                # cycling through the scheduled operational points
                for i = 1:nrowgd
                        (bst, transittype, scheduledtime)  = gd[i,2:end];

                        # this key allows us to access the info we stored in Dxml[], i.e., direction,line,distance_from_start
                        key = string(train, "-", bst);
                        
                        # build the block
                        nextbst = (i<nrowgd) ? gd[i+1, :bst] : bst; # "xxx";
                        blk = string(bst,"-",nextbst);
                   
                        # find the shortest path between bst and nextbst to see if some bst were missed 
                        shortestpath = findSequence(G, bst, nextbst);
                        
                        # notable exceptions: sometimes the shortest path is not the right one
                        if bst=="HFH4" && nextbst=="HF"
                                shortestpath = ["HFH4", "HFH3", "HFU22", "HFH2", "HFS14", "HFH1", "HF"];
                        end
                        # if the train misses a lot of bst we cannot tell where it passed from; therefore we teleport it in the new location.
                        if length(shortestpath) > POPPING_JUMPS
                                ispopping = true;
                        end

                        if !haskey(Dxml, key) # the train is not supposed to be in this bst...

                                pl("#1# $key -- $blk" );

                                DEBUG ≥ 4 && @info "Train $train is not supposed to be in $bst according to the schedule. Trying to fix."
                                # lets look at the next block if it is in the block list
                                direction = missing;
                                line = missing;
                                distance = 0;

                                # if the block exists
                                if haskey(BlkList, blk)
                                        direction = BlkList[blk].direction;

                                        # some blocks have more lines on them; we only consider the first one for the moment
                                        line = BlkList[blk].line[1]; # fix what happens if more lines exist here
                                        distance = BlkList[blk].length[1]; # fix what happens if more lines exist here

                                        DEBUG ≥ 3 && length(BlkList[blk].line)>1 && @warn "Line ambiguity for train $key in block $blk";

                                        # its length will be added
                                        iscumul = true;
                                elseif bst==nextbst # if these two are the same in the PAD, we are arriving and departing from a stationwe
                                        distance = 0;
                                        (direction, line) = dfout[end, [:direction, :line]];
                                end
                               
                        else
                                (direction, line, distance) = Dxml[key];
                                
                                cumuldist = distance;
                        end
                        
                        if ismissing(direction)
                                pl("#2a# $key");
                                direction = dfout[end, :direction];
                        end
                        if ismissing(line)
                                pl("#2b# $key");
                                line = dfout[end, :line];
                        end

                        pl("#3# ", (train*poppy, bst, transittype, direction, line, cumuldist, scheduledtime));
                        push!(dfout, (train*poppy, bst, transittype, direction, line, cumuldist, scheduledtime));

                        
                        if 0 < length(shortestpath)-2 <= POPPING_JUMPS
                                DEBUG ≥ 1 && @info "Filling $(length(shortestpath)-2) timetable holes between $bst and $nextbst for train $train"
                                # println("$bst->$nextbst:", length(shortestpath));
                                totlen = 0;
                                for w = 1:length(shortestpath)-1
                                        block = string(shortestpath[w],"-",shortestpath[w+1]);
                                        totlen += BlkList[block].length[1];
                                end
                             
                                starttime = scheduledtime;
                                endtime = gd[i+1, :scheduledtime];
                                cumullen = 0;
                                for w = 1:length(shortestpath)-2
                                        block = string(shortestpath[w],"-",shortestpath[w+1]);
                                        cumullen += BlkList[block].length[1];
                                        if line ∉ BlkList[block].line
                                                line = BlkList[block].line[1];
                                                direction = BlkList[block].direction;
                                        end
                                        DEBUG ≥ 3 && length(BlkList[block].length)>1 && @warn "Length ambiguity for train $train in block $block";
                                        
                                        t = starttime + floor(Int, (endtime-starttime)/totlen*cumullen);
                                        b = shortestpath[w+1];
                                        ttype = "p";
                                        cumuldist += cumullen;
                                        DEBUG ≥ 2 && @info "\tAdding $b for train $train";
                                        push!(dfout, (train*poppy, b, ttype, direction, line, cumuldist, t));
                                end
                        end
                        
                        if iscumul cumuldist += distance; end

                        if ispopping
                                DEBUG ≥ 1 && @info "Popping train $train from $bst to $nextbst because of $(length(shortestpath)) jumps";
                                poppy = string("_pop_", nextbst);
                                ispopping = false;
                                cumuldist = 0;
                        end
                end
        end

 
        dfout
end

function passingStation!(df::DataFrame, dfsta::DataFrame)::DataFrame

        @info "Estimating passing time through stations";
        
        sort!(df, [:train, :scheduledtime]);

        for i in 1:nrow(df)
                r = df[i,:];
                train = r[:train];
                if r[:bst] ∈ dfsta.id && r[:transittype] == "p" # passing through station
                        nextr = df[i+1,:];
                        if train==nextr[:train]
                                d1 = r[:distance]; d2 = nextr[:distance];
                                t1 = r[:scheduledtime]; t2 = nextr[:scheduledtime];
                                Δt = t2-t1;
                                if d2 - d1 <= STATION_LENGTH
                                        push!(df, (train, r[:bst], "P", r[:direction], r[:line], d1, floor(Int, (t1+t2)/2)));
                                        continue;
                                end
                                v = (d2-d1)/Δt;
                                t = floor(Int, t1 + STATION_LENGTH/v);
                                d = d1 + STATION_LENGTH;
                                push!(df, (train, r[:bst], "P", r[:direction], r[:line], d, t));
                                #r[:transittype] = "p1";
                        else
                                #@warn "Passing train $train is not the same as $(nextr[:train]) on next line";
                                d = r[:distance] + STATION_LENGTH;
                                t = FAST_STATION_TRANSIT_TIME + r[:scheduledtime];
                                push!(df, (train, r[:bst], "P", r[:direction], r[:line], d, t));
                                
                        end
                end
        end
        df
end

"""
Find joined trains and create a unique train
"""
function handleJoinedTrains!(df::DataFrame)::DataFrame

        sort!(df, [:train,:scheduledtime]);
    
        @info "Handling joined trains"
        # return df;
        # build the events at operational points, e.g.,  Dict("1525886940-B" => ["EC_164", "REX_5585"])
        D = Dict{String,Set{String}}();
        for r in eachrow(df)
                key = string(r.scheduledtime,"-",r.bst);
                get!(D,key,Set{String}());
                push!(D[key], r.train);
        end
    
        # remove events with only one train. p[2] or last(p) accesses the values of dictionaries.
        filter!(p-> length(p[2])>1, D);
    
        # Build co-occurrences of trains, e.g., Dict( Set(["IC_502", "IC_512"]) => 95)
        J = Dict{Set{String},Int}();
        for s in values(D)
                J[s] = get(J, s, 0) + 1;
        end
    
        # consider trains joined if their events coincide more than 4 times
        filter!(p->last(p)>4, J);
        
        # remove overlapping subsets
        for s in keys(J)
                for p in keys(J)
                s == p && continue;
                issubset(p,s) && delete!(J,p);
                end
        end

        # open("joined.csv", "w") do OUT
        #         for (k,v) in J
        #                 println(OUT, "$k,$v");
        #         end
        # end

        # the train field gets larger than 15 bytes
        df.train = String31.(df.train);

        # after detaching trains are sent to dfnew
        dfnew = similar(df, 0); # empty similar dataframe
        
        for k in keys(J)
            # k = Set(["REX_2639","R_7939","R_9993"]);
            trains = sort(collect(k));
            ntrains = length(trains);

            dft = similar(df,0);
            dflocal = similar(df,0);
            
            for train in trains
                append!(dft,  df[df.train .== train, :]);
            end
            
            gd = groupby(dft, [:bst,:scheduledtime]);
            
            for d in gd
                du = unique(d);
                convoy = join(sort(du.train),"+");
                push!(dflocal, (convoy, du[1,2:end]...));
            end
            
            sort!(dflocal, [:scheduledtime]);
    
            dflocalnew = similar(dflocal,0);

            dtc = "_dtc";
            # IsDetached = Set{String}();
            was_attached = already_detached = false;
            for r in eachrow(dflocal)
                train = r.train;
    
                # if it's a convoy
                if occursin("+", train)
                    if already_detached && ntrains == 2
                        trains = split(train,"+");
                        for t in trains
                            push!(dflocalnew, (t*dtc, r[2:end]...));
                            # println((t*dtc, r[2:end]...));
                        end
                        continue;
                    end
    
                    was_attached = true;
                    push!(dflocalnew, r);
                    # continue;
                else
                    if was_attached
                        push!(dflocalnew, (r.train*dtc, r[2:end]...));
                        already_detached = true;
                    else
                        push!(dflocalnew, r);
                    end
                end
    
    
            end
            
            append!(dfnew, dflocalnew);
            
        end
        unique!(dfnew);

        # find the affected trains
        S = Set{String}();
        for k in keys(J)
                S = union(S,k);
        end
    
        # remove them from the total schedule
        filter!(x->x.train ∉ S, df);
    
        # append the new convoys and trains
        append!(df, dfnew);
    
        sort!(df, [:train,:scheduledtime]);
        return df;
end

function composeTimetable(padfile::String, xmlfile::String, stationfile::String, outfile="timetable.csv")
        @info "Composing the timetable";

        dfpad = loadPAD(padfile);
        dfxml = loadXML(xmlfile);
        dfsta = CSV.read(stationfile, DataFrame);

        # (file, _) = splitext(xmlfile);
        # outblkfile = "blocks-$file.csv";
        dfblk = findBlocks(dfxml); #, outblkfile);
        
        cleanBstPADXML!(dfpad,dfxml);
        
        dfout = trainMatch(dfpad,dfxml,dfblk);

        passingStation!(dfout,dfsta);

        handleJoinedTrains!(dfout);

        @info "Saving timetable on file \"$outfile\"";
        sort!(dfout, [:train, :scheduledtime, :distance])
        CSV.write(outfile, dfout);
end

function composeXMLTimetable(padfile::String, xmlfile::String, stationfile::String, outfile="timetable.csv")
        @info "Composing the timetable using XML and the trains listed in PAD";

        dfpad = loadPAD(padfile);
        dfxml = loadXML(xmlfile);
        dfsta = CSV.read(stationfile, DataFrame);

        # (file, _) = splitext(xmlfile);
        # outblkfile = "blocks-$file.csv";
        dfblk = findBlocks(dfxml); #, outblkfile);
        
        cleanBstPADXML!(dfpad,dfxml);
        
        dfout = trainMatchXML(dfpad,dfxml,dfblk);

        passingStation!(dfout,dfsta);

        handleJoinedTrains!(dfout);
        
        @info "Saving timetable on file \"$outfile\"";   
        sort!(dfout, [:train, :scheduledtime, :distance]); 
        CSV.write(outfile, dfout);
end

function generateBlocks(xmlfile::String, 
                        rinfbkfile = "rinf-blocks.csv", 
                        rinfopfile = "rinf-OperationalPoints.csv",
                        outblkfile = "blocks.csv",
                        outopfile  = "stations.csv")   

        @info "Building a complete block file and adding onetrack property";

        dfxml = loadXML(xmlfile);
        xmlbk = findBlocks(dfxml);
        # WARNIG: we did not remove operational points not in common with PAD
 
        # xmlbk  = CSV.File(xmlbkfile)  |> DataFrame;
    rinfbk = CSV.File(rinfbkfile) |> DataFrame;
    rinfop = CSV.File(rinfopfile) |> DataFrame;

    Bk = Dict{String,TrackNr}();
    for r in eachrow(rinfbk)
            op1,op2,line,ntracks,length = r[:];

            # simmetrizziamo e pigliamo ntracks, poi aggiungiamo una colonna :ismono a xmlbk
            # con 1 se un binario solo. 
            ismono = ifelse(ntracks==1, ONETRACK, TWOTRACKS);
            blk = string(op1,"-",op2,"-",line);
            Bk[blk] = ismono;
            blk = string(op2,"-",op1,"-",line);
            Bk[blk] = ismono;
    end

    xmlbk.tracks = Vector{Int}(undef, nrow(xmlbk));
    xmlbk.ismono = Vector{Int}(undef, nrow(xmlbk));
    for r in eachrow(xmlbk)
        block,line,_length,_direction = r[:];
        blk = string(block,"-",line);
        r[:ismono] = get(Bk, blk, UNASSIGNED) |> Int; # -1 == unassigned
        r[:tracks] = 1; # nr of tracks is 1 for every block but may change with the try and catch
    end

    @info "Saving complete block information on file \"$outblkfile\"";
    CSV.write(outblkfile, sort(xmlbk, :block));

    @info "Looking for stations and places with more usable tracks";
    places_type = ["station", "small station", "passenger stop", "junction"];
    filter!(x-> x.type ∈ places_type, rinfop);
    select!(rinfop, [:id, :ntracks, :nsidings]);

    if isfile(EXTRA_STATION_FILE)
        @info "Appending extra stations found in $EXTRA_STATION_FILE";
        df = CSV.read(EXTRA_STATION_FILE, DataFrame);
        append!(rinfop, df);
    else
        @warn "No $EXTRA_STATION_FILE file found."
    end

    @info "Saving station information to file \"$outopfile\"";
    CSV.write(outopfile, sort(rinfop));

end

function sanityCheck(timetablefile = "timetable.csv", blkfile="blocks.csv", stationfile="stations.csv")
        @info "Doing a sanity check on the produced files"

        dt = CSV.File(timetablefile, select=[:train,:bst]) |> DataFrame;
        ds = CSV.File(stationfile, select=[:id]) |> DataFrame;
        db = CSV.File(blkfile, select=[:block]) |> DataFrame;
        select!(db, :block => ByRow(x->split(x,"-")) => [:op1,:op2]);

        sett = Set(unique(dt.bst));
        sets = Set(unique(ds.id));
        setb = Set(unique(vcat(db.op1,db.op2)));

        @info "There are $(length(setdiff(sets,sett))) stations not appearing in the timetable. This is not a problem since they do not appear in the PAD data.";
        if length(setdiff(sett,setb)) > 0
                @warn "There are $(length(setdiff(sett,setb))) operational points that are in the timetable and not in the blocks. This is a problem";
        end

        S = Set{String}();
        gt = groupby(dt, :train);
        for g in gt
                last = "";
                for r in eachrow(g)
                        if r.bst == last
                                push!(S,last);
                        end
                        last = r.bst;
                end
        end

        Sdiff = setdiff(S,sets);
        if length(Sdiff) > 0
                @warn "Some operational points seem to be stations but are not reported in the station file";
                println("List of operational points that seem to be stations but are not reported in \"$stationfile\":\n$Sdiff");
                println("Add them in the tabu list in preprocessing/scanxml.jl or in the extra-stations.csv")
        end
        @info "Sanity check done."
end

function padfile_from_date(file_base="PAD-Zuglaufdaten-20")::String
        
        day = join(reverse(split(date,".")), "-");
    
        return source_path*file_base*"$day.csv"; 
end

function xmlfile_from_date()::String
        year = split(date, ".")[3];
        return source_path * "xml-20$year.csv";
end

function configure()
        # padfile = "rex5803pad.csv";
        # xmlfile = "xml-2018.csv";
        
        if in_file == ""
                timetablefile = target_path*"timetable-$date.csv"
                padfile=padfile_from_date();
        else
                timetablefile = target_path*"timetable_$in_file"
                padfile = source_path * in_file; #inputfile_from_date(date,source_path)
        end

        
        xmlfile     = xmlfile_from_date();
        rinfbkfile  = source_path*"rinf-blocks.csv";
        rinfopfile  = source_path*"rinf-OperationalPoints.csv";
        outblkfile  = target_path*"blocks.csv";
        stationfile = target_path*"stations.csv";

        generateBlocks(xmlfile, rinfbkfile, rinfopfile, outblkfile, stationfile); 

        if xml_schedule
                composeXMLTimetable(padfile,xmlfile, stationfile, timetablefile);
        else
                composeTimetable(padfile,xmlfile, stationfile, timetablefile);
        end

        # (file, _) = splitext(xmlfile);
        # xmlbkfile = "blocks-$file.csv";


        sanityCheck(timetablefile, outblkfile, stationfile);
end

configure();
