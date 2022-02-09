using ArgParse

function parse_commandline()
    s = ArgParseSettings()

    @add_arg_table s begin

        "--ini", "-i"
            help = "path for the .ini file"
            arg_type = String
            default = "../data/simulation_data/par.ini"

        "--test"
            help = "int for running time or btime on simulation, default 0"
            arg_type = Int
            range_tester=x->issubset(x,[0,1,2])
            default = 0

        "--multi_simulation"
            help = "a flag for running multiple simulations"
            action = :store_true

        "--inject_delays"
            help = "a flag for making the program search for delays to inject in /data/delays/ repo;
                    every file corresponds to a different simulation;
                    if is couples with one_simulation flag, takes the first ordered delay file"
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
