using DataFrames, CSV, Dates

# function dateToSeconds(d::AbstractString)::Int
# """
# Given a string in the format "yyyy-mm-dd HH:MM:SS"
# returns the number of seconds elapsed from the epoch
# """
#     dt::DateTime = Dates.DateTime(d, "dd.mm.yyyy HH:MM:SS")
#     return Int(floor(datetime2unix(dt)))
#     #return (Dates.hour(dt)*60+Dates.minute(dt))*60+Dates.second(dt)
# end
# function dateToSeconds(d::Int)::Int
# """
# If the input is an Int do nothing
# assuming that it is already the number of seconds elapsed from the epoch
# """
#     return d
# end
# function dateToSeconds(d::Missing)::Missing
# """
# If the input is missing do nothing
# """
#     return missing
# end

function findBlocks(file::String, outfile="out.csv")::DataFrame

    #BlkList = Dict{String, Int}();
#    for file in files # "pad-sample.csv"; #files[1];

        df = DataFrame(CSV.File(file));
        # cleaning already done in scanxml.jl
        # dropmissing!(df,:bst);
        # # building list of non useful bst
        # ops = unique(df.bst);
        # km = filter(x->startswith(x,"KM "), ops);
        # ix = filter(x->startswith(x,r"I\d+"), ops);
        # Tabu = Set([km;ix]);
        # filter!(row -> !(row.bst ∈ Tabu), df);

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
                ismissing(sec) && (sec=df_train.line[n-2];);
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
    CSV.write(outfile, sort(D,:block));
    D
end

function df2gml(df::DataFrame)
    F = select(D,
            :block => ByRow(x-> split(x,"-")) => [:from,:to],
            :line);
    nodes = unique([F.from;F.to]);

    open("out.gml", "w") do OUT
        println(OUT, "graph\n[");
        for n in nodes
            println(OUT, "  node\n  [");
                println(OUT, "    id $n\n    label \"$n\"");
            println(OUT, "  ]");
        end
        for i = 1:nrow(F)
            println(OUT, "  edge\n  [");
                println(OUT, "    source $(F.from[i])\n    target $(F.to[i])");
                println(OUT, "    label \"$(F.line[i])\"");
            println(OUT, "  ]");
        end
        println(OUT, "]");
    end
end

D = findBlocks("xml-2018.csv", "xml-2018-blocks.csv");

df2gml(D);
