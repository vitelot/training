include("extern.jl")
include("initialize.jl")
include("parameters.jl")
include("functions.jl")
include("simulation.jl")

using Profile
using InteractiveUtils

using ArgParse

function parse_commandline()
    s = ArgParseSettings()

    @add_arg_table s begin
        "--opt1"
            help = "an option with an argument"
        "--opt2", "-o"
            help = "another option with an argument"
            arg_type = Int
            default = 0
        "--flag1"
            help = "an option without argument, i.e. a flag"
            action = :store_true

        "--ini", "-i"
            help = "path for the .ini file"
            arg_type = String
            default = "../data/simulation_data/par.ini"
        # "arg1"
        #     help = "a positional argument"
        #     required = true
    end

    return parse_args(s)
end


function main()

    if VERSION < v"1.6"
        println("Please upgrade Julia to at least version 1.6. Exiting.")
        exit()
    end

    parsed_args = parse_commandline()


    file=parsed_args["ini"]

    loadOptions(file);


    #if passed an argument, it is the input file path
    # if isempty(ARGS)
    #     file = "../data/simulation_data/par.ini"
    #     loadOptions(file);
    # else
    #     loadOptions(ARGS[1])
    # end

    Opt["print_flow"] && println("Options loaded, starting the program.")

    RN = loadInfrastructure();
    FL = loadFleet();

    if isdir(Opt["imposed_delay_repo_path"])
        delays_array,number_simulations = loadDelays() #Arr{Dataframe}, each is delay imposed in one simulation
    else
        delays_array,number_simulations=[],1
    end



    for simulation_id in 1:number_simulations

        Opt["print_flow"] && println("##################################################################")
        Opt["print_flow"] && println("Starting simulation number $simulation_id")
        Opt["print_notifications"] && println(stderr,"Starting simulation number $simulation_id.")

        isempty(delays_array) || imposeDelays(FL,delays_array,simulation_id)

        if Opt["simulate"]
            simulation(RN, FL)  && (println("returned 1 , restarting");)
            Opt["TEST"]>0 && runTest(RN,FL)
        else
            return (RN,FL)
        end

    end
    nothing
end

main()
