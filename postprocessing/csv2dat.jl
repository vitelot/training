using DataFrames,CSV;

filelist = readdir(".");
filter!(endswith(".csv"), filelist);

for file in filelist
    # file = filelist[1]
    df = CSV.read(file, DataFrame);
    outfile = splitext(file)[1]*".dat";
    CSV.write(outfile, df, header=false, delim=" ");
end

