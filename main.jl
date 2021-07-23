include("extern.jl")
include("initialize.jl")

function main()

    RN = loadInfrastructure()

end

R = main()
println(dump(R))
