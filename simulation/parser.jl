using ArgParse

function parse_commandline()
    s = ArgParseSettings()

    @add_arg_table s begin
        # "--opt1"
        #     help = "an option with an argument"
        # "--opt2", "-o"
        #     help = "another option with an argument"
        #     arg_type = Int
        #     default = 0
        # "--flag1"
        #     help = "an option without argument, i.e. a flag"
        #     action = :store_true

        "--ini", "-i"
            help = "path for the .ini file"
            arg_type = String
            default = "../data/simulation_data/par.ini"

        "--test"
            help = "int for running time or btime on simulation"
            arg_type = Int
            range_tester=x->issubset(x,[0,1,2])
            default = 0
        # "arg1"
        #     help = "a positional argument"
        #     required = true
    end

    return parse_args(s)
end
