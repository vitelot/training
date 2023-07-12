"""
Takes two folder containing the csv files of simulation output
and determines and plots the delays at destination.
"""



using CSV, DataFrames, Plots;

function cumul!(V::Vector{Int})
    filter!(x->x>0, V);
    sort!(V)
    r = collect(length(V):-1:1);
    r = r./r[1];
    (V, r)
end

function main(dir1="/Users/servedio/prgs/training/simulation/data/rotations", 
              dir2= "/Users/servedio/prgs/training/simulation/data/no-rotations") 

    files_rot = readdir(dir1);
    files_norot = readdir(dir2);

    filter!(startswith("timetable_simulation"), files_rot);
    filter!(startswith("timetable_simulation"), files_norot);
    if isempty(files_rot) || isempty(files_norot)
        @error "Files not found";
        exit(1);
    end

    delayList_rot = Int[];
    for file in files_rot 
        # file = "timetable_simulation_0001.csv";

        df = CSV.read("$dir1/$file", DataFrame);

        gd = groupby(df, :trainid);

        for g in gd
            gs = sort(g, :t_real);
            delay = gs[end, :t_real] - gs[end, :t_scheduled];
            push!(delayList_rot, delay);
        end
    end

    delayList_norot = Int[];
    for file in files_norot 
        # file = "timetable_simulation_0001.csv";



        df = CSV.read("$dir2/$file", DataFrame);

        gd = groupby(df, :trainid);

        for g in gd
            gs = sort(g, :t_real);
            delay = gs[end, :t_real] - gs[end, :t_scheduled];
            push!(delayList_norot, delay);
        end
    end

    (del_rot, r_rot) = cumul!(delayList_rot);
    (del_norot, r_norot) = cumul!(delayList_norot);

    dfout = DataFrame(delay=del_rot, cumulprob=r_rot);
    CSV.write("final_dest_delays_rotations.csv", dfout);

    dfout = DataFrame(delay=del_norot, cumulprob=r_norot);
    CSV.write("final_dest_delays_norotations.csv", dfout);

    @info "Building the figure";
    plot(del_rot, r_rot,
        xscale=:log10,
        yscale=:log10,
        xguide="delay (s)",
        yguide="cumulative probability",
        label="with rotations",
        lw=4
        # xlims=(10,9000),
        # ylims=(1,1000)
        );
    plot!(del_norot, r_norot,
        label="no rotations",
        lw = 3
    );
    @info "\tand saving it."
    savefig("figure.pdf");
end

main()
