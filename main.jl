include("extern.jl")
include("initialize.jl")
include("functions.jl")
include("simulation.jl")

function main()

    loadOptions()

    Opt["print_flow"] && println("Starting the program.")

    RN = loadInfrastructure()
    FL = loadFleet()

    simulation(RN, FL)

end

main()
