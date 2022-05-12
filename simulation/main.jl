@info "Loading libraries"
include("extern.jl")
include("initialize.jl")
include("parameters.jl")
include("functions.jl")
include("blocks.jl")
include("simulation.jl")
include("parser.jl")
@info "Compiling."


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

        Opt["test"]>0 && runTest(RN,FL)

        simulation(RN, FL)
    else
        return (RN,FL)
    end

    nothing
end


function multiple_sim(RN::Network, FL::Fleet)

    if isdir(Opt["imposed_delay_repo_path"])
        delays_array,number_simulations = loadDelays()
    else
        Opt["print_notifications"] && println(stderr,"Running multiple_sim() without imposing delay files makes no sense. Running a simple simulation.")
        delays_array=[]
        number_simulations=1
    end

    for simulation_id in 1:number_simulations

        Opt["print_flow"] && println("##################################################################")
        Opt["print_flow"] && println("Starting simulation number $simulation_id")
        Opt["print_notifications"] && (@info "Starting simulation number $simulation_id.")

        isempty(delays_array) || imposeDelays(FL,delays_array,simulation_id)


        simulation(RN, FL, simulation_id)  && (println("successfully ended , restarting");)


    end
    nothing
end


function main()
    @info "Starting main()"

    #CLI parser
    parsed_args = parse_commandline()

    #load parsed_args["ini"] file infos
    loadOptions(parsed_args);

    #load the railway net
    RN = loadInfrastructure();
    FL = loadFleet();

    if parsed_args["catch_conflict"]
        catch_conflict(RN,FL,parsed_args)
    else
        #one or multiple simulations
        if parsed_args["multi_simulation"]
            multiple_sim(RN, FL)
        else
            one_sim(RN, FL)
        end
    end

end

main()
