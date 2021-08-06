include("extern.jl")
include("initialize.jl")
include("functions.jl")
include("simulation.jl")

function main()

    loadOptions()

    Opt["print_flow"] && println("Starting the program.")

    RN = loadInfrastructure()
    FL = loadFleet()

    if Opt["simulate"]
        simulation(RN, FL)
        if Opt["TEST"]
            runTest(RN,FL)
        end
    else
        return (RN,FL)
    end
end

main()
