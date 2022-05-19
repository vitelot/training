function Rotations(df::DataFrame)
@info "Generating train reassignements"

#df = DataFrame(CSV.File("PAD-Zuglaufdaten_2019-01.csv"));

#filter!( row -> row[:Betriebstag]=="25.03.19", df);

    rename!(df, :"BST Code Anlieferung" => :bst)
    #rename!(df, :Betriebstag            => :date)
    #rename!(df, :Istzeit                => :rtime)
    #rename!(df, :"Messpunkt Bez"        => :kind)
    rename!(df, :"Sollzeit R"           => :stime)
    rename!(df, :"Zuglaufmodus Code"    => :code)
    df.trainid = string.(df.Zuggattung, "_",  df.Zugnr)

    select!(df, ([:trainid,:code,:stime, :Tfz1,:Tfz2,:Tfz3,:Tfz4,:Tfz5]))

    df.stime = dateToSeconds.(df.stime)

    filter!(row -> row.code =="Z", df)

#    Train = unique(df.trainid);
    allLok = [df.Tfz1; df.Tfz2; df.Tfz3; df.Tfz4; df.Tfz5];
    allLok = string.(allLok);
    filter!(s->s!="missing", allLok);
#    Loco = unique(allLok)

    sort!(df, :stime)

    LokoTrain = Dict{String, Vector{String}}();
    S = Set{String}();

    for i in 1:nrow(df)
        t1 = df.Tfz1[i]; t2 = df.Tfz2[i]; t3 = df.Tfz3[i]; t4 = df.Tfz4[i]; t5 = df.Tfz5[i];
        L = [t1, t2, t3, t4, t5];
        filter!(!ismissing, L)
        train = df.trainid[i];
        in(train, S) && continue;
        push!(S,train);
        for l in string.(L)
            get!(LokoTrain, l, String[]);
            push!(LokoTrain[l], train);
        end
    end

    D = Dict{String,String}();
    for l in keys(LokoTrain)
        V = LokoTrain[l]
        length(V) < 2 && continue;
        for i = 2:length(V)
#            V[i]=="R_2357" && @show V[i-1], l;
            D[V[i]] = V[i-1];
        end
    end

    dd = DataFrame(train=collect(keys(D)), waitsfor=collect(values(D)))
    file = "../data/simulation_data/rotations.csv";
    CSV.write(file, dd);
    println("Rotation file $file saved");
end
