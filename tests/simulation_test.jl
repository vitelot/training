using Test


@testset "Simulation" begin

    fname="./scripts/out"
    out=read(fname, String)

    str="WARNING: station MD-MD has only one platform.\nTotal delay at the end of simulation is 42\n"

    @test out==str
end

include("../simulation/extern.jl")
include("../simulation/functions.jl")

#netStatus(S::Set{String}, BK::Dict{String,Block}; hashing::Bool=false)

@testset "functions" begin

    S=Set{String}(["SB29953"])
    BK=Dict{String,Block}("FLDH1-FLDU2" => Block("FLDH1-FLDU2", false, 1, 1, Set{String}(["SB29953"])), "FLDU2-FLDH1" => Block("FLDU2-FLDH1", false, 1, 0, Set{String}()))

    schedule=[Transit("SB29541", "WSP", "Ankunft", 200), Transit("SB29541", "WSP", "Abfahrt", 100)]
    # hashing=true

    @test netStatus(S, BK; hashing=true)==0x121c97cea605b461

    @test netStatus(S, BK; hashing=false)=="FLDH1-FLDU2:Set([\"SB29953\"]) "

    @test netStatus(Set{String}(), BK)==""

    @test sort!(schedule)[1].duetime==100
end
