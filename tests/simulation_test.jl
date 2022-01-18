using Test


@testset "Simulation" begin

    fname="./run/out"
    out=read(fname, String)

    str="Total delay at the end of simulation is 42\n"

    println(out)
    println(str)

    @test out==str
end

include("../simulation/functions.jl")
include("../simulation/extern.jl")

@testset "functions" begin

    S=(["SB29953"])
    BK=("FLDH1-FLDU2" => Block("FLDH1-FLDU2", 1, 0, Set{String}()), "FLDU2-FLDH1" => Block("FLDU2-FLDH1", 1, 0, Set{String}()))

    hashing=true


    @test netStatus(S, BK; hashing)
end
