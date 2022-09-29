@info "Loading libraries";

using CSV, DataFrames;
include("MyGraphs.jl");
include("MyDates.jl");
using .MyGraphs, .MyDates;

UInt = Union{Int,Missing};
UString = Union{String,Missing};

POPPING_JUMPS = 10; # number of jumps allowed to fill in timetable holes
DEBUG = true;#false;#true;

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

        # keep only running trains Z=scheduled, E=substitution
        # filter!(x->x.runningtype ∈ ["Z","E"], bigpad);
        # remove OP at the border
        filter!(x->!startswith(x.bstname,"Staatsgrenze"), bigpad);
        
        select!(bigpad,
        [:traintype, :trainnr] => ByRow((x,y)->string(x,"_",y)) => :train,
        :bst => ByRow(x->replace(x,r"[ _]+"=>"")) => :bst,
        :transittype => ByRow(x->translateGerman(x)) => :transittype,
        :scheduledtime
        );
        
        transform!(bigpad, :scheduledtime => ByRow(x->dateToSeconds(x)) => :scheduledtime);
        
        return(bigpad);
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
        # remove OP at the border
        filter!(x->!startswith(x.bstname,"Staatsgrenze"), xml);

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
        @info "Removing the operational points that do not appear in both datasets"

        bstpad = unique(select(dfpad, :bst));
        bstxlm = unique(select(dfxml, :bst));
        
        aj = antijoin(bstpad,bstxlm, on=:bst);
        filter!(x->(x.bst ∉ aj.bst), dfpad);
        
        aj = antijoin(bstxlm,bstpad, on=:bst);
        filter!(x->(x.bst ∉ aj.bst), dfxml);
        
        nothing
end


function findBlocks(df::DataFrame, outfile="")::DataFrame
        @info "Finding blocks by aggregating two consecutive lines"
    #BlkList = Dict{String, Int}();
#    for file in files # "pad-sample.csv"; #files[1];

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
#    end
    # Bs = sort(BlkList, byvalue=true, rev=true);
    unique!(D);
    
    if outfile !== "" 
        @info "Saving blocks on file \"$outfile\"";
        CSV.write(outfile, sort(D,:block));
    end

    D
end
"""
    trainMatch(dfpad::DataFrame, dfxml::DataFrame)::DataFrame

TBW
"""
function trainMatch(dfpad::DataFrame, dfxml::DataFrame, dfblk::DataFrame)::DataFrame
        @info "Building a clean timetable"
        gdpad = groupby(dfpad, :train);
        gdxml = groupby(dfxml, :train);
        Dxml = Dict{String, DataFrameRow}();

        G = loadGraph(copy(dfblk), type="directed");

        BlkList = Dict{String, Block}();
        for r in eachrow(dfblk)
                (name, line, distance, direction) = r[:];
                get!(BlkList, name, Block(name, String[], Int[], direction));
                push!(BlkList[name].line, line); 
                push!(BlkList[name].length, distance);
        end
        # return BlkList;

        for gd in gdxml
                train = gd.train[1];

                for i = 1:nrow(gd)
                        # train = gd.train[1]
                        key = string(train, "-", gd.bst[i]);
                        Dxml[key] = gd[i, [:direction, :line, :distance]];
                end
        end
        
        dfout = DataFrame(train =UString[], bst=UString[], transittype=UString[],
                direction=UInt[],
                line=UString[], distance=UInt[],
                scheduledtime=UInt[]
                );
        
        for gd in gdpad
                nrowgd = nrow(gd);
                nrowgd>1 || continue; # remove one line trains

                train = gd.train[1];
                poppy = ""; ispopping=false;
                cumuldist = distance = 0; iscumul = false;

                for i = 1:nrowgd
                        (bst, transittype, scheduledtime)  = gd[i,2:end];
                        key = string(train, "-", bst);
                        nextbst = (i<nrowgd) ? gd[i+1, :bst] : bst; # "xxx";
                        blk = string(bst,"-",nextbst);
                        shortestpath = findSequence(G, bst, nextbst);

                        if length(shortestpath) > POPPING_JUMPS
                                # println("$bst->$nextbst:", length(shortestpath));
                                ispopping = true;
                        end

                        if !haskey(Dxml, key) # the train is not supposed to be in this bst...
                                # push!(dfout, (train, bst, transittype, missing, missing, missing, scheduledtime));
                                # continue;


                                # DEBUG && @info "Train $train is not supposed to be in $bst according to the schedule. Trying to fix."
                                # lets look at the next block if it is in the block list
                                direction = missing;
                                line = missing;
                                distance = 0;

                                if haskey(BlkList, blk)
                                        direction = BlkList[blk].direction;
                                        line = BlkList[blk].line[1]; # fix what happens if more lines exist here
                                        distance = BlkList[blk].length[1]; # fix what happens if more lines exist here

                                        length(BlkList[blk].line)>1 && @warn "Line ambiguity for train $key in block $blk";

                                        iscumul = true;
                                        #@warn "must add the length";
                                elseif bst==nextbst
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
                                line = dfout[end, :line];
                        end

                        push!(dfout, (train*poppy, bst, transittype, direction, line, cumuldist, scheduledtime));

                        # if length(shortestpath) == 3 
                        #         # println("$bst->$nextbst:", length(shortestpath));
                        #         starttime = scheduledtime;
                        #         endtime = gd[i+1, :scheduledtime];
                        #         blk1 = string(shortestpath[1],"-",shortestpath[2]);
                        #         blk2 = string(shortestpath[2],"-",shortestpath[3]);
                        #         len1 = BlkList[blk1].length[1];
                        #         len2 = BlkList[blk2].length[1];
                        #         t2 = starttime + floor(Int, (endtime-starttime)/(len1+len2)*len1);
                        #         b = shortestpath[2];
                        #         ttype = "p";
                        #         cumuldist += len1;
                        #         @info "Adding $b for train $train";
                        #         push!(dfout, (train*poppy, b, ttype, direction, line, cumuldist, t2));
                        # end
                        if 2 < length(shortestpath) <= POPPING_JUMPS+2
                                DEBUG && @info "Filling $(length(shortestpath)-2) timetable holes between $bst and $nextbst for train $train"
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

                                        length(BlkList[block].length)>1 && @warn "Length ambiguity for train $train in block $block";
                                        
                                        t = starttime + floor(Int, (endtime-starttime)/totlen*cumullen);
                                        b = shortestpath[w+1];
                                        ttype = "p";
                                        cumuldist += cumullen;
                                        DEBUG && @info "\tAdding $b for train $train";
                                        push!(dfout, (train*poppy, b, ttype, direction, line, cumuldist, t));
                                end
                        end
                        
                        if iscumul cumuldist += distance; end

                        if ispopping
                                DEBUG && @info "Popping train $train from $bst to $nextbst because of $(length(shortestpath)) jumps";
                                poppy = string("_pop_", nextbst);
                                ispopping = false;
                                cumuldist = 0;
                        end
                end
        end
        dfout
end

# dfout = trainMatch(dfpad,dfxml,dfblk);
function composeTimetable(padfile::String, xmlfile::String, outfile="timetable.csv")

        dfpad = loadPAD(padfile);
        dfxml = loadXML(xmlfile);
        
        
        (file, _) = splitext(xmlfile);
        outblkfile = "blocks-$file.csv";
        dfblk = findBlocks(dfxml, outblkfile);
        
        cleanBstPADXML!(dfpad,dfxml);
        
        # CSV.write("pippo.csv", dfxml);
        
        


        dfout = trainMatch(dfpad,dfxml,dfblk);

        # CSV.write("pippo.csv", dfout);
        @info "Saving timetable on file \"$outfile\"";
        CSV.write(outfile, dfout);
end

padfile = "PAD-Zuglaufdaten-2018-05-09.csv";
# padfile = "rex5803pad.csv";
xmlfile = "xml-2018.csv";

composeTimetable(padfile,xmlfile);