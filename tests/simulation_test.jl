using Test


@testset "Simulation" begin

    fname="./run/out"
    out=read(fname, String)

    str="Total delay at the end of simulation is 42\n"

    println(out)
    println(str)

    @test out==str
end

include("../simulation/extern.jl")
include("../simulation/functions.jl")

#netStatus(S::Set{String}, BK::Dict{String,Block}; hashing::Bool=false)

@testset "functions" begin

    S=Set{String}(["SB29953"])
    BK=Dict{String,Block}("FLDH1-FLDU2" => Block("FLDH1-FLDU2", 1, 0, Set{String}()), "FLDU2-FLDH1" => Block("FLDU2-FLDH1", 1, 0, Set{String}()))
    hashing=true

    @test netStatus(S, BK; hashing)==0xbd32f78d463d7cfb
    @test netStatus(S, BK; hashing=false)==0xbd32f78d463d7cfb
    @test netStatus(Set{String}(), BK; hashing)==""
end
