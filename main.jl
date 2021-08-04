include("extern.jl")
include("initialize.jl")
include("functions.jl")
include("simulation.jl")

function main()
    println("Starting the program.")
    RN = loadInfrastructure()
    FL = loadFleet()

    simulation(RN, FL)

end

main()
