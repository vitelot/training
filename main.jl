include("extern.jl")
include("initialize.jl")
include("functions.jl")
include("simulation.jl")

function main()
    println("Compilation ended. Starting the program.")
    # RN = loadInfrastructure()
    FL = loadFleet()

    simulation(FL)

end

main()
