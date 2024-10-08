@info "Loading libraries"
include("extern.jl")
include("initialize.jl")
include("parameters.jl")
include("functions.jl")
include("blocks.jl")
include("simulation.jl")
include("parser.jl")
@info "Compiling."


function one_sim(RN::Network, FL::Fleet)::Nothing
    delay_folder::String = Opt["imposed_delay_repo_path"];
    inject_delays::Bool  = Opt["inject_delays"];
    print_flow::Bool     = Opt["print_flow"];
    run_test::Bool       = Opt["test"];
    simulate::Bool       = Opt["simulate"];

    #inserting delays from data/delays/ repo.
    if isdir(delay_folder)
         delays_array = loadDelays();
         isempty(delays_array) || imposeDelays(FL, delays_array[1]);

    elseif inject_delays
         printstyled("The option --inject_delays is active, but no path specified to the folder with delays in par.ini\n", bold=true);

    end

    print_flow && println("##################################################################")
    print_flow && println("Starting simulation")

    simulation(RN, FL);

    return;
end


function multiple_sim(RN::Network, FL::Fleet; num_sims=-1)::Nothing

    delay_folder::String = Opt["imposed_delay_repo_path"];
    print_flow::Bool     = Opt["print_flow"];

    if isdir(delay_folder)
        delays_array = loadDelays();
    else
        println(stderr,"Running multiple_sim() without imposing delay files makes no sense. Running one simulation with no delays.")
        one_sim(RN,FL);
        return;
    end
    
    if num_sims==-1
        number_simulations = length(delays_array);
    else
        number_simulations = num_sims
    end
    @info "Going to run $number_simulations simulations."
    for simulation_id in 1:number_simulations

        @info("##################################################################");
        # print_flow && println("Starting simulation number $simulation_id")
        @info "Starting simulation number $simulation_id";

        isempty(delays_array) || imposeDelays(FL, delays_array[simulation_id]);

        if simulation(RN, FL, simulation_id)
            @info("Trains got stuck in simulation nr $simulation_id, discarding.");
        else
            @info("Simulation nr $simulation_id successfully ended, restarting.");
        end

        resetSimulation(FL); # set trains dynamical variables to zero
        resetDynblock(RN); # reinitialize the blocks

    end
    return;
end

"""
If test mode is enabled, runs speed test without printing simulation results on std out
"""
function runTest(RN::Network, FL::Fleet)::Nothing
    
    # be sure everything is compiled
    simulation(RN, FL); 
    # reload everything
    RN = loadInfrastructure();
    FL = loadFleet();
    
    @time simulation(RN, FL)
    
    return;
end

function main()
    @info "Starting main()";

    
    #CLI parser
    parsed_args = parse_commandline();
    
    #load parsed_args["ini"] file infos
    loadOptions(parsed_args);
    
    simulate::Bool  = Opt["simulate"];
    run_test::Bool  = Opt["test"];
    num_sims::Int   = Opt["num_sims"]

    if parsed_args["version"]
        println("Program version $ProgramVersion");
        return;
    end

    #load the railway net
    RN = loadInfrastructure();
    # @warn "just exit for a test; saving the infra to file RN.txt";
    # open("../simulation/data/RN.txt", "w") do OUTtest
    #     pprintln(OUTtest, RN);
    # end
    # exit();

    FL = loadFleet();
    # @warn "just exit for a test; saving the fleet to file FL.txt";
    # open("../simulation/data/FL.txt", "w") do OUTtest
    #     pprintln(OUTtest, FL);
    # end
    # exit();

    if !simulate
        return (RN,FL);
    end

    if run_test
        runTest(RN,FL);
        return;
    end

    if parsed_args["catch_conflict"]
        catch_conflict(RN,FL,parsed_args);
    else
        #one or multiple simulations
        if parsed_args["multi_simulation"]
            if num_sims == -1
                multiple_sim(RN, FL);
            else
                multiple_sim(RN, FL, num_sims=num_sims);
            end
        else
            one_sim(RN, FL);
        end
    end

    @info "Done."
    return;
end

main()
