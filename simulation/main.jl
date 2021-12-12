include("extern.jl")
include("initialize.jl")
include("parameters.jl")
include("functions.jl")
include("simulation.jl")

using Profile

function main()

    if VERSION < v"1.6"
        println("Please upgrade Julia to at least version 1.6. Exiting.")
        exit()
    end

    loadOptions();

    Opt["print_flow"] && println("Options loaded, starting the program.")

    RN = loadInfrastructure();
    FL = loadFleet();

    isdir(Opt["imposed_delay_repo_path"]) && ((delays_array,number_simulations) = loadDelays())
    #(delays_array,number_simulations) = loadDelays()#Arr{Dataframe}, each is delay imposed in one simulation

    println(number_simulations)


    for simulation_id in 1:number_simulations
        #res=1
        #simulation_id=613
        Opt["print_flow"] && println("##################################################################")
        Opt["print_flow"] && println("Starting simulation number $simulation_id")
        Opt["print_notifications"] && println(stderr,"Starting simulation number $simulation_id.")

        !isempty(delays_array) && imposeDelays(FL,delays_array,simulation_id)

        if Opt["simulate"]
            simulation(RN, FL)  && (println("returned 1 , restarting");FL = loadFleet();) #;RN = loadInfrastructure()
            Opt["TEST"]>0 && runTest(RN,FL)
        else
            return (RN,FL)
        end
        nothing

    end
end

main()
