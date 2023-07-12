using CSV,DataFrames,Plots,Dates;

function dateToSeconds(d::AbstractString)::Int
    dt::DateTime = Dates.DateTime(d, "dd.mm.yyyy HH:MM:SS")
    return Int(floor(datetime2unix(dt)))
    #return (Dates.hour(dt)*60+Dates.minute(dt))*60+Dates.second(dt)
end

function string2Date(d::AbstractString)
    ds = parse.(Int,split(d,"."));
    Date(ds[3]+2000,ds[2],ds[1])
end

function cumul!(V::Vector{Int})
    filter!(x->x>0, V);
    sort!(V)
    r = collect(length(V):-1:1);
    r = r./r[1];
    (V, r)
end

function main(file = "../data/OeBB/2018/PAD-Zuglaufdaten_2018-02.csv")

    df = CSV.read(file, select=[1,4,9,10], DataFrame);
    dropmissing!(df);
    filter!(x->!isempty(x[3])&&!isempty(x[4]), df);

    select!(df,
        1 => ByRow(string2Date) => :day,
        2 => :trainnr,
        #    [3,4] => ByRow((x,y)->dateToSeconds(y)-dateToSeconds(x)) => :delay 
        3 => ByRow(dateToSeconds) => :t_sched,
        4 => ByRow(dateToSeconds) => :t_real
    );

    filter!(x->month(x.day)==5, df)

    gd = groupby(df, [:day, :trainnr]);

    delayList = Int[];

    for g in gd
        gs = sort(g, :t_real);
        delay = gs[end, :t_real] - gs[end, :t_sched];
        push!(delayList, delay);
    end

    filter!(x->x>0, delayList);

    del,r = cumul!(delayList);

    dfout = DataFrame(delay=delayList, cumulprob=r);
    CSV.write("final_dest_delays_may18.csv", dfout);

    @info "Building the figure";
    plot(del, r,
        xscale=:log10,
        yscale=:log10,
        xguide="delay (s)",
        yguide="cumulative probability",
        label="May 2018",
        lw=4
        # xlims=(10,9000),
        # ylims=(1,1000)
        );
    

    @info "\tand saving it."
    savefig("figure-final_dest_delays_may18.pdf");
end

main()
