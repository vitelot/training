"""
configure.jl

OLD README, must be changed
Input: 

Output:

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

include("parser.jl");
include("strategies.jl")
#CLI parser
parsed_args = parse_commandline()

@info "Loading libraries";

using CSV, DataFrames, Dates;
include("MyGraphs.jl");
include("MyDates.jl");
using .MyGraphs, .MyDates;
include("exo_delays.jl");

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
const ARRIVE_IN_STATION = 20; # if a departure without arrive is detected, assume the train arrived this amount of seconds before

config_path::String   = parsed_args["config_data_path"]

# list of stations not found in the rinf data
EXTRA_STATION_FILE = "$(config_path)/extra-stations.csv";
# list of stations that are incorrect in rinf
STATION_EXCEPTION_FILE = "$(config_path)/station-exceptions.csv";
# list of blocks that are incorrect in rinf
BLOCK_EXCEPTION_FILE = "$(config_path)/block-exceptions.csv";
# list of trains to remove because are redundant (overlap with others and generate conflicts)
TRAINS_TO_REMOVE_FILE = "$(config_path)/trains-to-remove.csv";
# list of trains to reroute to Pottendorfer line (10601) from Sudbahn (10501)
# at Wiener Neustadt up to Wien Meidling
#TRAINS_TO_REROUTE_FILE = "$(config_path)/trains-to-reroute-to-Pottendorfer.csv"
TRAINS_TO_REROUTE_FILE = "$(config_path)/trains-to-reroute.csv"
TRAINS_TO_DECOUPLE_FILE = "$(config_path)/decoupled_rotations.csv"

# #CLI parser
# parsed_args = parse_commandline()

date::String          = parsed_args["date"] # default = "09.05.18"
in_file::String       = parsed_args["file"]
source_path::String   = parsed_args["source_data_path"]
target_path::String   = parsed_args["target_data_path"]
nr_exo_delays::Int    = parsed_args["exo_delays"];
delays_only::Bool     = parsed_args["delays_only"];
use_real_time         = parsed_args["use_real_time"];
find_rotations::Bool  = parsed_args["rotations"];
pad_schedule::Bool    = parsed_args["pad_schedule"];
select_line::String   = parsed_args["select_line"];
cut_day::Bool         = parsed_args["cut_day"];
skip::Bool            = parsed_args["skip"];
reroute::Bool         = parsed_args["reroute"]

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

function padfile_from_date(file_base="PAD-Zuglaufdaten-20")::String
        
        day = join(reverse(split(date,".")), "-");
    
        return source_path*file_base*"$day.csv"; 
end

function xmlfile_from_date()::String
        year = split(date, ".")[3];
        return source_path * "xml-20$year.csv";
end

function selectLine!(df::DataFrame)::Nothing
        
        linefile = source_path*select_line*".csv";
        
        @info "Restricting the network to the operational points defined in file $linefile";
        
        if !isfile(linefile)
                error("Line file $linefile not found.")
        end

        dfline = CSV.read(linefile, comment="#", DataFrame);
        filter!(x->x.bst ∈ dfline.bst, df);

        return;
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
                types = String,
                skipto = 2) |> DataFrame;
        
        # use a dirty trick to work with real time instead of scheduled
        use_real_time && rename!(bigpad, :scheduledtime => :unusedtime, :realtime => :scheduledtime);

        dropmissing!(bigpad, :scheduledtime);
        filter!(x->length(x.scheduledtime)>0, bigpad );

        # keep only running trains Z=scheduled, E=substitution
        filter!(x->x.runningtype ∈ ACCEPTED_TRAJ_CODE, bigpad);
        
        # remove OP at the border
        filter!(x->!startswith(x.bstname,"Staatsgrenze"), bigpad);

        # remove strange bst "B  G" homonym of "BG"
        # println(filter(x->x.bst=="BG", bigpad));
        # println(bigpad);
        # filter!(x->!==(x.bst,"B  G"), bigpad);
        
        select!(bigpad,
                [:traintype, :trainnr] => ByRow((x,y)->string(x,"_",y)) => :trainid,
                :bst => ByRow(x->replace(x,r"[ _]+"=>"")) => :bst,
                :transittype => ByRow(x->translateGerman(x)) => :transittype,
                :scheduledtime => ByRow(x->dateToSeconds(x)) => :scheduledtime,
                :loco1, :loco2, :loco3, :loco4, :loco5
        );
        
        if cut_day
                day = Date(unix2datetime(minimum(bigpad.scheduledtime)));
                @info "Restricting the analysis to day $day ignoring trains over midnight."
                filter!(x->Date(unix2datetime(x.scheduledtime))==day, bigpad);
        end

        sort(bigpad, [:trainid, :scheduledtime]);
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
        
        if pad_schedule 
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
                @info "\tSaving blocks on file \"$outfile\"";
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
        gdpad = groupby(dfpad, :trainid);
 
        # based on the scheduled PAD data, we build a dictionary with
        # key = train-bst and value with the scheduled time at that bst; to be used to fill the voids in the xml. 
        Dpad = Dict{String, Int}();
        for gd in gdpad
                train = gd.trainid[1];

                for r in eachrow(gd)
                        key = string(train, "-", r.bst,"-", r.transittype);
                        Dpad[key] = r.scheduledtime;
                end
        end
         
        if isfile(TRAINS_TO_REMOVE_FILE)
                @info "Processing trains to remove in file $TRAINS_TO_REMOVE_FILE";
                df = CSV.read(TRAINS_TO_REMOVE_FILE, comment="#", DataFrame);
                removetrainlist = df.trainid;
        end

        # these are the trains we shall consider
        padtrainlist = unique(dfpad.trainid);
        xmltrainlist = unique(dfxml.train);

        # select all trains in pad that are in xml
        trainlist = filter(x-> x ∈ xmltrainlist && x ∉ removetrainlist, padtrainlist);
        
        # this will be our processed schedule
        dfout = DataFrame(trainid =UString[], bst=UString[], transittype=UString[],
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
        gdxml = groupby(dfout, :trainid);

        # The remaining time gaps are just a few, so we decide to delete them.
        # Julia does not allow the deletion from a subdataframe
        # so we fill a array and will delete at the end in another sweep.
        ToDelete = String[];
        for gd in gdxml
                nrowgd = nrow(gd);
                train = gd.trainid[1];

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
                                        @info("\tFirst point has still zero time: $(gd[i,:trainid]),$(gd[i,:bst])");
                                        continue;
                                end
                                # get info from previous time and distance
                                t0 = gd[i-1, :scheduledtime];
                                d0 = gd[i-1, :distance];
                                
                                i1 = i+1
                                if i1 > nrowgd
                                        @info("\tLast point has still zero time: $(gd[i,:trainid]),$(gd[i,:bst])");
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
        length(ToDelete) > 0 && @info("\tDeleting $ToDelete since their initial and final scheduled time cannot be inferred");
        filter!(x-> string(x.trainid,"-",x.bst) ∉ ToDelete, dfout);
        
        gdxml = groupby(dfout, :trainid);
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
        gdpad = groupby(dfpad, :trainid);
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
        dfout = DataFrame(trainid =UString[], bst=UString[], transittype=UString[],
                direction=UInt[],
                line=UString[], distance=UInt[],
                scheduledtime=UInt[]
                );
        
        # we cycle through all trains
        for gd in gdpad
                nrowgd = nrow(gd);
                nrowgd>1 || continue; # remove one line trains

                train = gd.trainid[1];
                poppy = ""; ispopping=false;
                cumuldist = distance = 0; iscumul = false;

                # cycling through the scheduled operational points
                for i = 1:nrowgd
                        (bst, transittype, scheduledtime)  = gd[i,2:end];

                        # this key allows us to access the info we stored in Dxml[], i.e., direction,line,distance_from_start
                        key = string(train, "-", bst);
                        
                        # build the block
                        nextbst = (i<nrowgd) ? gd[i+1, :bst] : bst; # "xxx";
                        nextschedtime = (i<nrowgd) ? gd[i+1, :scheduledtime] : scheduledtime+3; # "xxx";

                        # find the shortest path between bst and nextbst to see if some bst were missed 
                        shortestpath = findSequence(G, bst, nextbst);
                        
                        if scheduledtime == nextschedtime
                                if length(shortestpath)>2
                                        DEBUG > 1 && @info("Same transit time at two consecutive ops: $train $bst $nextbst");
                                        # we would like to swap this row and the next but requires more coding.
                                        # therefore we skip this row and let the following algo interpolate the missing station
                                        # as if it was not there.
                                        # we also need to remove the last row in the dfout since it has
                                        # filled an inexistent gap. 
                                        DEBUG==1 && @info "Removing last added transit since it filled an inexistent gap."
                                        deleteat!(dfout, nrow(dfout)); 
                                        continue;
                                end
                        end

                        blk = string(bst,"-",nextbst);
                        
                        # notable exceptions: sometimes the shortest path is not the right one
                        if bst=="HFH4" && nextbst=="HF"
                                shortestpath = ["HFH4", "HFH3", "HFU22", "HFH2", "HFS14", "HFH1", "HF"];
                        end
                        # if the train misses a lot of bst we cannot tell where it passed from; therefore we teleport it in the new location.
                        if length(shortestpath) > POPPING_JUMPS
                                ispopping = true;
                        end

                        if !haskey(Dxml, key) # the train is not supposed to be in this bst...

                                # pl("#1# $key -- $blk" );

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
                                direction = dfout[end, :direction];
                        end
                        if ismissing(line)
                                blk = string(dfout.bst[end], "-", bst);
                                # pl("#2a# $key $bst $blk $(dfout.bst)");

                                # trains may change their path and go onto another line
                                # we need to ensure the block is the correct one referring to the new path
                                line = dfout[end, :line];
                                if haskey(BlkList,blk) && line ∉ BlkList[blk].line # if is not a station and ...
                                        line = BlkList[blk].line[1];
                                        direction = BlkList[blk].direction;
                                        cumuldist += BlkList[blk].length[1];
                                        dfout.line[end] = line; # in the simul, block's line is that of the initial bst
                                end
                        end

                        # pl("#3# ", (train*poppy, bst, transittype, direction, line, cumuldist, scheduledtime));
                        push!(dfout, (train*poppy, bst, transittype, direction, line, cumuldist, scheduledtime));

                        
                        if 0 < length(shortestpath)-2 <= POPPING_JUMPS
                                DEBUG ≥ 1 && @info "Filling $(length(shortestpath)-2) timetable holes between $bst and $nextbst for train $train"
                                # println("$bst->$nextbst:", length(shortestpath));

                                totlen = 0; # used to interpolate the passing time
                                for w = 1:length(shortestpath)-1
                                        block = string(shortestpath[w],"-",shortestpath[w+1]);
                                        totlen += BlkList[block].length[1];
                                end
                             
                                starttime = scheduledtime;
                                endtime = gd[i+1, :scheduledtime];
                                cumullen = 0;

                                # println(dfout[end,:]);
                                
                                for w = 1:length(shortestpath)-2
                                        block = string(shortestpath[w],"-",shortestpath[w+1]);
                                        cumullen += BlkList[block].length[1];
                                        if line ∉ BlkList[block].line
                                                line = BlkList[block].line[1];
                                                direction = BlkList[block].direction;
                                        end
                                        # println("$train $block $(BlkList[block])");

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

        @info "Scanning for anomalous sequences at stations";
        for i in 1:nrow(dfout)-1
                r   = dfout[i,:];
                nr  = dfout[i+1,:];
                # if arrival and departure coincide than the train is passing by
                if r.trainid==nr.trainid && r.bst==nr.bst && r.scheduledtime==nr.scheduledtime
                        r.trainid = "delete";
                        nr.transittype = "p";
                end
        end
 
        filter!(x-> x.trainid != "delete", dfout)
end

function passingStation!(dftab::DataFrame, dfsta::DataFrame)::DataFrame

        @info "Estimating passing time through stations";
        
        # sort!(df, [:train, :scheduledtime]);

        dfplus = similar(dftab, 0);

        gd = groupby(dftab, :trainid);

        for df in gd
                issorted(df.scheduledtime) || sort!(df, :scheduledtime);
                train = df.trainid[1];
                nrowdf = nrow(df);
                # cure the arrival and pass at stations that must be arrival+departure
                for i in 1:nrowdf-1
                        r = df[i,:];
                        nextr = df[i+1,:];
                        # after an arrive there must be a departure, not a pass
                        if r.bst == nextr.bst && r.transittype=="a" && nextr.transittype=="p"
                                nextr.transittype = "d";
                                continue;
                        end
                end

                for i in 1:nrowdf-1
                        r = df[i,:];
                        if r[:bst] ∈ dfsta.id && r[:transittype] == "p" # passing through station
                                nextr = df[i+1,:];
                                d1 = r[:distance]; d2 = nextr[:distance];
                                t1 = r[:scheduledtime]; t2 = nextr[:scheduledtime];
                                Δt = t2-t1;
                                if d2 - d1 <= STATION_LENGTH
                                        push!(dfplus, (train, r[:bst], "P", r[:direction], r[:line], d1, floor(Int, (t1+t2)/2)));
                                        continue;
                                end
                                v = (d2-d1)/Δt;
                                t = floor(Int, t1 + STATION_LENGTH/v);
                                d = d1 + STATION_LENGTH;
                                push!(dfplus, (train, r[:bst], "P", r[:direction], r[:line], d, t));

                                # if train==nextr[:train]
                                #         #r[:transittype] = "p1";
                                # else
                                #         #@warn "Passing train $train is not the same as $(nextr[:train]) on next line";
                                #         d = r[:distance] + STATION_LENGTH;
                                #         t = FAST_STATION_TRANSIT_TIME + r[:scheduledtime];
                                #         push!(df, (train, r[:bst], "P", r[:direction], r[:line], d, t));
                                        
                                # end
                        end
                end
                r = df[nrowdf,:]; # last row in the schedule
                if r[:bst] ∈ dfsta.id && r[:transittype] == "p" # passing through station
                        d = r[:distance] + STATION_LENGTH;
                        t = FAST_STATION_TRANSIT_TIME + r[:scheduledtime];
                        push!(dfplus, (train, r[:bst], "P", r[:direction], r[:line], d, t));

                end
        end
        append!(dftab, dfplus);
        sort!(dftab, [:trainid, :scheduledtime])
end

"""
Find joined trains and create a unique train
"""
function handleJoinedTrains!(df::DataFrame)::DataFrame

        sort!(df, [:trainid,:scheduledtime]);
    
        @info "Handling joined trains"
        # return df;
        # build the events at operational points, e.g.,  Dict("1525886940-B" => ["EC_164", "REX_5585"])
        D = Dict{String,Set{String}}();
        for r in eachrow(df)
                key = string(r.scheduledtime,"-",r.bst);
                get!(D,key,Set{String}());
                push!(D[key], r.trainid);
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
        df.trainid = String31.(df.trainid);

        # after detaching trains are sent to dfnew
        dfnew = similar(df, 0); # empty similar dataframe
        
        for k in keys(J)
            # k = Set(["REX_2639","R_7939","R_9993"]);
            trains = sort(collect(k));
            ntrains = length(trains);

            dft = similar(df,0);
            dflocal = similar(df,0);
            
            for train in trains
                append!(dft,  df[df.trainid .== train, :]);
            end
            
            gd = groupby(dft, [:bst,:scheduledtime]);
            
            for d in gd
                du = unique(d);
                convoy = join(sort(du.trainid),"+");
                push!(dflocal, (convoy, du[1,2:end]...));
            end
            
            sort!(dflocal, [:scheduledtime]);
    
            dflocalnew = similar(dflocal,0);

            dtc = "_dtc";
            # IsDetached = Set{String}();
            was_attached = already_detached = false;
            for r in eachrow(dflocal)
                train = r.trainid;
    
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
                        push!(dflocalnew, (r.trainid*dtc, r[2:end]...));
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
        filter!(x->x.trainid ∉ S, df);
    
        # append the new convoys and trains
        append!(df, dfnew);
    
        sort!(df, [:trainid,:scheduledtime]);
        return df;
end

function Rotations(padfile::String, timetablefile::String, outfile::String)
        @info "Generating train reassignements";
        
        df = loadPAD(padfile);

        dftab = CSV.read(timetablefile, select=[:trainid], comment="#", DataFrame);
        alltrains = unique(dftab.trainid);

        select!(df, 
                :trainid,# => :trainid,
                :scheduledtime => :stime, 
                r"loco");

        # Find start and end time of trains
        gd = groupby(df, :trainid);
        TrainStartTime = Dict{String,Int}();
        TrainEndTime = Dict{String,Int}();
        for dd in gd
                if !issorted(dd.stime)
                        @warn "In Rotations(), train's transits are not sorted";
                end
                train = dd.trainid[1];
                TrainStartTime[train] = dd.stime[1];
                TrainEndTime[train]   = dd.stime[end];
        end

        sort!(df, :stime)

        LokoTrain = Dict{String, Vector{String}}();
        S = Set{String}();

        locosymbols = filter(x->occursin("loco",x), names(df));
        # associate locos with their trains
        # newloko = 1;
        for r in eachrow(df)
                train = r.trainid;
                in(train, S) && continue;

                L = String[];
                for li in locosymbols
                    isempty(r[li]) || push!(L, string(r[li]));
                end
                push!(S,train);
                for l in L
                        get!(LokoTrain, l, String[]);
                        push!(LokoTrain[l], train);
                end
                # if isempty(L) # no locos found -> assign a default one
                #         LokoTrain[string("9999.", newloko)] = [train];
                #         newloko += 1;
                # end
        end

        D = Dict{String,String}();
        for l in keys(LokoTrain)
                V = LokoTrain[l]
                length(V) < 2 && continue; # the loco serves one train only
                for i = 2:length(V)
                        # V[i]=="R_2357" && @show V[i-1], l;
                        # create a dependency if train schedule do not overlap
                        if TrainStartTime[V[i]] > TrainEndTime[V[i-1]]
                                D[V[i]] = V[i-1];
                        end
                end
        end

        # for l in keys(LokoTrain)
        #     "SB_29890" in LokoTrain[l] && println("$l ", LokoTrain[l]);
        # end
        # exit();

        @info "Handling popping trains' reassignements";
        # if A waits for B and there is a popper of B, we let A wait for the last popper of B
        for (t,v) in D
                poppers = filter(startswith(v), alltrains);
                length(poppers) <= 1 && continue;
                (m,idx) = findmax(length, poppers);
                D[t] = poppers[idx];
        end

        # we link the poppers of A together
        poppers = filter(x->occursin("_pop_",x), alltrains);
        for p in poppers
                parts = split(p,"_pop_");
                l = length(parts);
                # do nothing if t does not pop
                l == 1 && continue;
                s = [parts[1]];
                # X_pop_zzz_pop_www waits for X_pop_zzz that waits for X
                for i = 2:l
                        push!(s, join(vcat(s[i-1],parts[i]), "_pop_"));
                        D[s[i]] = s[i-1];
                end
        end
        
        detachers = filter(x->occursin("_dtc",x), alltrains);
        for d in detachers
                maintrain = split(d, "_dtc")[1];
                D[d] = maintrain;
        end

        joiners = filter(x->occursin("+",x), alltrains);
        for j in joiners
                T = split(j,"+");
                # for t in T
                        # use only the first one since D can hold one value only
                        D[j] = split(T[1], "_pop")[1];
                # end
        end


        dd = DataFrame(train=collect(keys(D)), waitsfor=collect(values(D)))

        # Remove the decoupled trains
        df_decoupled = CSV.read("$(config_path)/decoupled_rotations.csv", header=[:train, :waitsfor], DataFrame)
        decoupled_trains = []
        for (ix, row) in enumerate(eachrow(df_decoupled))
            push!(decoupled_trains, (df_decoupled[ix, :train], df_decoupled[ix, :waitsfor]))
        end
        dd[!, :keep] .= true
        println(decoupled_trains)
        for (train, waitsfor) in decoupled_trains
            for row in eachrow(dd)
                if (row[:train] == train) && (row[:waitsfor] == waitsfor)
                    row[:keep] = false 
                end
            end
        end
        filter!(row -> row[:keep], dd)
        select!(dd, [:train, :waitsfor])

        # file = "../simulation/data/rotations.csv";
        @info("\tSaving rotations to file $outfile");
        CSV.write(outfile, dd);

        # let's also save the traction units
        select!(df, :trainid, r"loco");
        
        unique!(df);
        
        nc = ncol(df);
        newloko = 1;
        for r in eachrow(df)
                # r[1] == "EC_390" && println("### ", collect(r)," ", count(ismissing.(collect(r))));
                if count(isempty.(collect(r))) == nc-1 # no loco present
                        r[2] = string("9999.", newloko); # add a default one
                        newloko += 1;
                        # println(r)
                end
        end

        for p in poppers
                maintrain = split(p,"_pop_")[1];
                r = df[df.trainid .== maintrain, :];
                r.trainid = fill(p, length(r.trainid));
                append!(df, r);
        end
        for d in detachers
                maintrain = split(d,"_dtc")[1];
                r = df[df.trainid .== maintrain, :];
                r.trainid = fill(d, length(r.trainid));
                append!(df, r);
        end
        for j in joiners
                # for example: j = "SB_37630+REX_7630_pop_NFL"
                maintrain = split(split(j,"+")[1], "_pop")[1];
                r = df[df.trainid .== maintrain, :];
                r.trainid = fill(j, length(r.trainid));
                append!(df, r);
        end

        tractionfile = splitdir(outfile)[1] * "/traction_units.csv";
        @info("\tSaving traction units to file $tractionfile");
        CSV.write(tractionfile, sort(df, :trainid));

end
      
function checkAD(dt::DataFrame)
        # when a departure is found without an arrival it is because the arrival has been marked as 
        # Ausfall. We then assume that the train arrived in station ARRIVE_IN_STATION seconds before.
        @info "Checking arrive-departure combinations";
        dfappend = similar(dt, 0);
        gt = groupby(dt, :trainid);
        for g in gt
                lasttype = "";
                for r in eachrow(g)
                        type = r.transittype;
                        if type == "d" && lasttype != "a" && rownumber(r) > 1
                                @info ("\tDeparture with no arrive in train $(r.trainid), operational point $(r.bst)");
                                push!(dfappend, (r.trainid, r.bst, "a", r.direction, r.line, r.distance, r.scheduledtime-ARRIVE_IN_STATION));
                        end
                        lasttype = type;
                end
        end
        append!(dt, dfappend);

        nothing;
end

function composeTimetable(padfile::String, xmlfile::String, stationfile::String, outfile="timetable.csv")::Nothing
        @info "Composing the timetable";

        dfpad = loadPAD(padfile);
        dfxml = loadXML(xmlfile);
        dfsta = CSV.read(stationfile, DataFrame);

        dfblk = findBlocks(dfxml); #, outblkfile);
        
        cleanBstPADXML!(dfpad,dfxml);

        if !isempty(select_line) 
                selectLine!(dfpad);
                selectLine!(dfxml);
        end

        if pad_schedule
                dfout = trainMatch(dfpad,dfxml,dfblk);
        else
                dfout = trainMatchXML(dfpad,dfxml,dfblk);
        end

        # Rerouting to an alternate route
        if reroute
            for line in readlines(TRAINS_TO_REROUTE_FILE)
                if !startswith(line, '#')
                    line = split(line, ",")
                    trainid = String(line[1])
                    reroute_start = String(line[2])
                    reroute_via = String(line[3])
                    reroute_end = String(line[4])
                    @info "Rerouting $(trainid) at $(reroute_start) via $(reroute_via) up to $(reroute_end)..."
                    construct_rerouted_schedule!(dfout, 
                                         reroute_start=reroute_start, 
                                         reroute_via=reroute_via, 
                                         reroute_end=reroute_end, 
                                         trainid=trainid)
                    @info "Rerouting of $(trainid) done!"
                end
            end
            sort!(dfout, :trainid)
        end

        passingStation!(dfout,dfsta);

        handleJoinedTrains!(dfout);
        
        checkAD(dfout);

        @info "Saving timetable on file \"$outfile\"";
        sort!(dfout, [:trainid, :scheduledtime, :distance])
        CSV.write(outfile, dfout);

        nothing;
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
    xmlbk.superblock = Vector{Int}(undef, nrow(xmlbk));

    for r in eachrow(xmlbk)
        block,line,_length,_direction = r[:];
        blk = string(block,"-",line);
        r[:ismono] = get(Bk, blk, UNASSIGNED) |> Int; # -1 == unassigned
        r[:tracks] = 1; # nr of tracks is 1 for every block but may change with the try and catch
        r[:superblock] = 0; # if it is <=0 superblock is ignored by the sim
    end

    if isfile(BLOCK_EXCEPTION_FILE)
        @info "Reading block exceptions from file $BLOCK_EXCEPTION_FILE";
        df = CSV.read(BLOCK_EXCEPTION_FILE, types=[String,String,Int,Int,Int,Int], comment="#", DataFrame);
        for r in eachrow(df)
                idx = findfirst(xmlbk.block .== r.block .&& xmlbk.line .== r.line);
                if isnothing(idx)
                        # @warn "Block listed in the exceptions is not found: $(r.block),$(r.line)";
                        @info "\tNew block $(r.block)-$(r.line) found."
                        push!(xmlbk, r);
                else
                        xmlbk[idx, :tracks] = r.tracks;
                end
        end
    end

    # remove duplicates
    unique!(xmlbk, [:block,:line]);

    @info "\tSaving complete block information on file \"$outblkfile\"";
    CSV.write(outblkfile, sort(xmlbk, :block));

    @info "Looking for stations and places with more usable tracks";
    places_type = ["station", "small station", "passenger stop", "junction"];
    filter!(x-> x.type ∈ places_type, rinfop);
    select!(rinfop, [:id, :ntracks, :nsidings]);

    # add station exceptions that are wrong in the rinf 
    if isfile(STATION_EXCEPTION_FILE)
        @info "Processing station exceptions found in $STATION_EXCEPTION_FILE";
        df = CSV.read(STATION_EXCEPTION_FILE, comment="#", DataFrame);
        for r in eachrow(df)
                idx = findfirst(rinfop.id .== r.id);
                if isnothing(idx)
                        @warn "Exception station $(r.id) not found";
                        continue;
                end
                rinfop[idx, :] = r;
        end
    end

    if isfile(EXTRA_STATION_FILE)
        @info "Appending extra stations found in $EXTRA_STATION_FILE";
        df = CSV.read(EXTRA_STATION_FILE, comment="#", DataFrame);
        append!(rinfop, df);
    else
        @warn "No $EXTRA_STATION_FILE file found."
    end

    rinfop.superblock = zeros(Int, nrow(rinfop)); # if <=0 superblocks are ignored in the sim

    @info "\tSaving station information to file \"$outopfile\"";
    CSV.write(outopfile, sort(rinfop));

end

function sanityCheck(timetablefile = "timetable.csv", blkfile="blocks.csv", stationfile="stations.csv")
        @info "Doing a sanity check on the produced files"

        dt = CSV.File(timetablefile, select=[:trainid,:bst,:transittype]) |> DataFrame;
        ds = CSV.File(stationfile, select=[:id]) |> DataFrame;
        db = CSV.File(blkfile, select=[:block]) |> DataFrame;
        select!(db, :block => ByRow(x->split(x,"-")) => [:op1,:op2]);

        sett = Set(unique(dt.bst));
        sets = Set(unique(ds.id));
        setb = Set(unique(vcat(db.op1,db.op2)));

        @info "There are $(length(setdiff(sets,sett))) stations not appearing in the timetable.\n\tThis is not a problem since they do not appear in the PAD data.";
        if length(setdiff(sett,setb)) > 0
                @warn "There are $(length(setdiff(sett,setb))) operational points that are in the timetable and not in the blocks. This is a problem";
        end

        gt = groupby(dt, :trainid);
        for g in gt
                lasttype = "";
                for r in eachrow(g)
                        type = r.transittype;
                        if type == "d" && lasttype != "a" && rownumber(r) != 1
                                @warn ("Departure with no arrive in train $(r.trainid) ops $(r.bst)");
                        end
                        lasttype = type;
                end
        end

        # check for Station coverage
        S = Set{String}();
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
        @info "Sanity check done.";
        nothing;
end

function configure()::Nothing
        # padfile = "rex5803pad.csv";
        # xmlfile = "xml-2018.csv";
        
        if !isdir(target_path) 
                mkdir(target_path);
                @info "Folder $target_path has been created."
        end

        if in_file == ""
                timetablefile = target_path*"timetable-$date.csv"
                padfile=padfile_from_date();
        else
                timetablefile = target_path*"timetable_$in_file"
                padfile = source_path * in_file; #inputfile_from_date(date,source_path)
        end

        if nr_exo_delays>0 && delays_only
                SampleExoDelays(
                    "$(config_path)/NumberOfDelays.csv",
                    "$(config_path)/DelayList.csv",
                    "$(target_path)/timetable.csv",
                    "$(target_path)/delays/imposed_exo_delay.csv",
                    nr_exo_delays);
                return;    
        end

        xmlfile     = xmlfile_from_date();
        rinfbkfile  = source_path*"rinf-blocks.csv";
        rinfopfile  = source_path*"rinf-OperationalPoints.csv";
        outblkfile  = target_path*"blocks.csv";
        stationfile = target_path*"stations.csv";
        rotationfile= target_path*"rotations.csv";

        generateBlocks(xmlfile, rinfbkfile, rinfopfile, outblkfile, stationfile); 

        composeTimetable(padfile,xmlfile, stationfile, timetablefile);
        
        if find_rotations
                Rotations(padfile, timetablefile, rotationfile);
        end

        if nr_exo_delays>0
                SampleExoDelays(
                    "$(config_path)/NumberOfDelays.csv",
                    "$(config_path)/DelayList.csv",
                    "$(target_path)/timetable.csv",
                    "$(target_path)/delays/imposed_exo_delay.csv",
                    nr_exo_delays);
        end

        sanityCheck(timetablefile, outblkfile, stationfile);

        return;
end

configure();
