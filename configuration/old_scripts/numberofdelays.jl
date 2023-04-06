using CSV, DataFrames, Dates;

df = CSV.read("actual_exo_diff_delays_sim_input.csv", DataFrame);

gd = groupby(df, :date)

dfout = DataFrame(day=Date[], number=Int[]);
for g in gd
    day = g.date[1];
    num = length(g.date);
    push!(dfout, (day,num));
end

CSV.write("NumberOfDelays.csv", dfout);