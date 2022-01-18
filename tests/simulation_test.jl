using Test

@testset "Simulation" begin

    fname="./run/out"
    out=read(fname, String)

    str="Total delay at the end of simulation is 42\n"

    println(out)
    println(str)

    @test out==str
end
