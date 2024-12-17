using ArgParse

function parse_commandline()
    s = ArgParseSettings()

    @add_arg_table s begin

        "--version", "-v"
            help = "show the simulation's version"
            action = :store_true

        "--ini", "-i"
            help = "path for the .ini file"
            arg_type = String
            default = "../running/simdata/par.ini"

        "--output_path", "-o"
            help = "Folder where the generated timetables are to be stored"
            arg_type = String
            default = "../running/results"

        "--timetable_file", "-t"
            help = "override the path to the timetable file"
            arg_type = String
            default = ""

        "--block_file", "-b"
            help = "override the path to the file with block specifications"
            arg_type = String
            default = ""

        "--station_file", "-s"
            help = "override the path to the file with station specifications"
            arg_type = String
            default = ""

        "--speed_test"
            help = "perform a speed test on the simulation core using the @time macro -- disable all outputs"
            action = :store_true

        "--multi_simulation"
            help = "a flag for running multiple simulations"
            action = :store_true

        "--catch_conflict"
            help = "a flag for running routines for checking the structure of the railway. It is currently disabled."
            action = :store_true

        "--inject_delays"
            help = "The program searches for delays to inject in the simulation.
                    The corresponding files with the lists of trians to delay must be placed
                    in the folder specified in par.ini under imposed_delay_repo_path, which usually
                    is the /data/delays/ folder;
                    If the --multi_simulation flag is not specified, the first ordered delay file is used."
            action = :store_true

        "--num_sims"
            help = "The number of simulations to carry out. This number should at most be the number of
                    delay files available. By default the number of simulations would be equal to the 
                    total number of delay files."
            arg_type = Int
            default = -1

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
