include("extern.jl")
include("initialize.jl")
include("functions.jl")
include("simulation.jl")

function main()

    loadOptions();

    Opt["print_flow"] && println("Starting the program.")

    RN = loadInfrastructure();
    FL = loadFleet();

    if Opt["simulate"]
        simulation(RN, FL)
        Opt["TEST"] && runTest(RN,FL)
    else
        return (RN,FL)
    end
    nothing
end

main()
