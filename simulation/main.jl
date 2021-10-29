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

    delays_array= loadDelays()#Arr{Dataframe}, each is delay imposed in one simulation


    for simulation_id in 1:Opt["number_simulations"]

        Opt["print_flow"] && println("##################################################################")
        Opt["print_flow"] && println("Starting simulation number $simulation_id")
        Opt["print_notifications"] && println(stderr,"Starting simulation number $simulation_id.")

        imposeDelays(FL,delays_array,simulation_id)

        if Opt["simulate"]
            simulation(RN, FL)
            Opt["TEST"]>0 && runTest(RN,FL)
        else
            return (RN,FL)
        end
        nothing
        # if simulation_id == 2
        #      break
        # end
    end
end

main()
