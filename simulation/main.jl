include("extern.jl")
include("initialize.jl")
include("parameters.jl")
include("functions.jl")
include("simulation.jl")
include("parser.jl")


function main()

    if VERSION < v"1.6"
        println("Please upgrade Julia to at least version 1.6. Exiting.")
        exit()
    end

    #CLI parser
    parsed_args = parse_commandline()

    #load parsed_args["ini"] file infos
    loadOptions(parsed_args);

    #load the railway net
    RN = loadInfrastructure();
    FL = loadFleet();

    #one or multiple simulations
    if parsed_args["multi_simulation"]
        multiple_sim(RN, FL)
    else
        one_sim(RN, FL)
    end
end
















function one_sim(RN::Network, FL::Fleet)

    #inserting delays from data/delays/ repo..
    if isdir(Opt["imposed_delay_repo_path"])
         delays_array,number_simulations = loadDelays();
         #imposing first file delay, simulation_id=1
         imposeDelays(FL,delays_array,1)
     end

    Opt["print_flow"] && println("##################################################################")
    Opt["print_flow"] && println("Starting simulation")

    if Opt["simulate"]
        simulation(RN, FL)
        Opt["test"]>0 && runTest(RN,FL)
    else
        return (RN,FL)
    end

    nothing
end











function multiple_sim(RN::Network, FL::Fleet)

    if isdir(Opt["imposed_delay_repo_path"])
        delays_array,number_simulations = loadDelays()
    else
        Opt["print_notifications"] && println(stderr,"Running multiple_sim() without imposing delays file,no sense. Running simple simulation.")
        delays_array=[]
        number_simulations=1
    end

    for simulation_id in 1:number_simulations

        Opt["print_flow"] && println("##################################################################")
        Opt["print_flow"] && println("Starting simulation number $simulation_id")
        Opt["print_notifications"] && println(stderr,"Starting simulation number $simulation_id.")

        isempty(delays_array) || imposeDelays(FL,delays_array,simulation_id)

        if Opt["simulate"]
            simulation(RN, FL)  && (println("returned 1 , restarting");)
        else
            return (RN,FL)
        end

    end
    nothing
end



main()
