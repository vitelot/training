include("extern.jl")
include("initialize.jl")
include("parameters.jl")
include("functions.jl")
include("simulation.jl")

function main()

    if VERSION < v"1.6"
        println("Please upgrade Julia to at least version 1.6. Exiting.")
        exit()
    end

    loadOptions();

    Opt["print_flow"] && println("Starting the program.")

    RN = loadInfrastructure();
    FL = loadFleet();

    if Opt["simulate"]
        simulation(RN, FL)
        Opt["TEST"]>0 && runTest(RN,FL)
    else
        return (RN,FL)
    end
    nothing
end

main()
