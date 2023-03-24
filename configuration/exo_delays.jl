using CSV, DataFrames; #, Distributions, StatsBase

"""
It samples directly from the real data.
It first samples the number of delays per day to be injected,
then it samples the trains, blocks and respective delay from another file.
"""
function SampleExoDelays(
    fileNdelay    = ".data/NumberOfDelays.csv",
    fileDelayList = "./data/DelayList.csv",
    fileTimetable = "../simulation/data/timetable.csv",
    outfile       = "../simulation/data/delays/imposed_exo_delay.csv",
    nsamples::Int=1;
    cleanfolder=true)

    @info "Creating $nsamples sample days."
    @info "\tLoading data."

    dfn=DataFrame(CSV.File(fileNdelay, select=[:number]));
    dftbl=DataFrame(CSV.File(fileTimetable, select=[:trainid])); # Or Mon, Tue, ... Or timetable
    trains=unique(dftbl.trainid);

    df=DataFrame(CSV.File(fileDelayList));
    
    dropmissing!(df, :trainid);
    @info "\tSelecting the trains to be delayed."

    filter!(x-> x.trainid ∈ trains, df);      # Filter the trains present in the timetable in use

    select!(df, Not(:day)); # remove the day column - in the future select the timeframe you need

    dfnrow = nrow(df);
    baseoutfile, extension = splitext(outfile);

    cleanfolder && cleanFolder(dirname(outfile));

    for i in 1:nsamples
        n=rand(dfn.number); # Total number of exogeneous delays we inject
        sample_row_idxs = rand(1:dfnrow, n); # It samples n rows
        dfout = df[sample_row_idxs, :];
        sequence = lpad(i,4,"0");
        outfile = "$(baseoutfile)_$sequence" * "$extension";
        CSV.write(outfile, dfout);
        println("Exo delay file \"$outfile\" saved.");
    end
end

function cleanFolder(folder::String)::Nothing
    #dir = dirname(outfile);

    if !isdir(folder)
        mkdir(folder);
        @info "Delay repo folder \"$folder\" created";
    end

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

    nothing
end
