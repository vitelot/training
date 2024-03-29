using CSV, DataFrames #, Distributions, StatsBase


# function SamplePL(α=2.55)
# """
# It extracts a random value from the power law distribution
# """
#     d=60*rand(Float64)^(1/(1-α))   #60s is the mimimum delay value in the power-law distribution , 2.16 is the exponent
#     return round(Int64, d)
# end
#
#
# function GenerateExoDelays()
# """
# It takes the trains from the timetable, assign to them a probability based on a CSV,
# extracts the number n of exo. delays that has to be inserted, extract the BSTs,
# build the csv with exo. delays to be assigned
# """
#     dft=DataFrame(CSV.File("tipicaok.csv"))           #Or Mon, Tue, ... Or timetable
#     dtrains=unique(dft.trainid)
#
#     dfp=DataFrame(CSV.File("probabilities.csv"))
#     dfp=filter(:trainid => x-> x ∈dtrains,dfp)
#
#
#     d=LogNormal(4.26,0.46)
#     n=round(Int,rand(d))              #Total number of exogeneous delays we inject
#
#     sample_rows = sample(1:nrow(dfp), StatsBase.Weights(dfp.prob), n)  #It samples n rows based on their probabilities
#     dfp = dfp[sample_rows, :]
#
#     dfp[!,:delay] = [SamplePL() for i in 1:n]        # This adds the column of n random delays
#
#     dfp=select!(dfp, Not(:prob))
#
#
#     CSV.write("exo_delays", dfp, header=false)
# end



"""
It samples directly from the real data.
It first samples the number of delays per day to be injected,
then it samples the trains, blocks and respective delay from another file.
"""
function SampleExoDelays(
    fileNdelay    = "../simulation/data/hidden_data/NumberOfDelays.csv",
    fileTimetable = "../simulation/data/timetable.csv",
    fileDelayList = "../simulation/data/hidden_data/DelayList.csv",
    outfile       = "../simulation/data/delays/imposed_exo_delay.csv",
    nsamples::Int=1;
    cleanfolder=true)

    dfn=DataFrame(CSV.File(fileNdelay, select=[:number]));
    dftbl=DataFrame(CSV.File(fileTimetable, select=[:trainid]))         # Or Mon, Tue, ... Or timetable
    trains=unique(dftbl.trainid)

    df=DataFrame(CSV.File(fileDelayList))
    filter!(:trainid => x-> x ∈ trains, df)      # Filter the trains present in the timetable in use
    select!(df, Not(:day)); # remove the day column - in the future select the timeframe you need
    dfnrow = nrow(df);
    baseoutfile, extension = splitext(outfile);

    cleanfolder && cleanFolder(dirname(outfile));

    for i in 1:nsamples
        n=rand(dfn.number)                              # Total number of exogeneous delays we inject
        sample_row_idxs = rand(1:dfnrow, n) #sample(1:nrow(df),n)             # It samples n rows
        dfout = df[sample_row_idxs, :]
        sequence = lpad(i,4,"0");
        outfile = "$(baseoutfile)_$sequence" * "$extension";
        CSV.write(outfile, dfout)
        println("Exo delay file \"$outfile\" saved.")
    end
end

function cleanFolder(folder::String)
    #dir = dirname(outfile);
    dircontent = readdir(folder, join=true);
    # delete files ending in .csv but not starting with _ or .
    todelete = filter(x-> !isdir(x) && endswith(basename(x), r"\.csv") && !startswith(basename(x),r"_|\."), dircontent);
    length(todelete)==0 && return;

    #dirlist = filter(isdir, dircontent);
    i=0;
    newbakdir = "";
    while true
        i += 1;
        newbakdir = joinpath(folder, "BAK"*lpad(i,3,"0"));
        !isdir(newbakdir) && break;
    end
    mkdir(newbakdir);

    for file in todelete
        mv(file, joinpath(newbakdir, basename(file)));
    end
    printstyled("Old delay files moved into folder $newbakdir\n", bold=true);
end
