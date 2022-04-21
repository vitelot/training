using ArgParse

function parse_commandline()
    s = ArgParseSettings()

    @add_arg_table s begin

        "--ini", "-i"
            help = "path for the .ini file"
            arg_type = String
            default = "../data/simulation_data/par.ini"

        "--test", "-t"
            help = "Int for running time or btime on simulation, default 0"
            arg_type = Int
            range_tester=x->issubset(x,[0,1,2])
            default = 0

        "--multi_simulation"
            help = "a flag for running multiple simulations"
            action = :store_true

        "--catch_conflict_flag"
            help = "a flag for running routines for checking the structure of the railway"
            action = :store_true

        "--inject_delays"
            help = "The program searches for delays to inject in the simulation.
                    The corresponding files with the lists of trians to delay must be placed
                    in the folder specified in par.ini under imposed_delay_repo_path, which usually
                    is the /data/delays/ folder;
                    If the --multi_simulation flag is not specified, the first ordered delay file is used."
            action = :store_true

        "--multi_stations_flag"
            help = "a flag for making the stations have a preferential direction"
            action = :store_true

            # "--opt1"
            #     help = "an option with an argument"
            # "--opt2", "-o"
            #     help = "another option with an argument"
            #     arg_type = Int
            #     default = 0
            # "--flag1"
            #     help = "an option without argument, i.e. a flag"
            #     action = :store_true
            # "arg1"
            #     help = "a positional argument"
            #     required = true

    end

    return parse_args(s)
end
