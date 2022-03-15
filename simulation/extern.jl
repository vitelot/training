"""
This file contains the definition of data structures,
useful shortcuts,
and the packages to be loaded
"""

using DataFrames,DataStructures, CSV, Dates, BenchmarkTools;
#using StatsBase, PrettyPrint;


using Profile
using InteractiveUtils

Opt = Dict{String,Any}()

#struct not used for now
struct OPoint # Operational Point: Betriebstelle
    id::String # id name
    idx::Int # numerical index
    lat::Float64
    long::Float64
    parent::Vector{String}
    child::Vector{String}
    isStation::Bool
end

mutable struct Block
    id::String #each block has got its own name
    # idx::Int # and number
    # minT::Int #minimum time of block travelling in seconds
    # dueT::Int #due time of travelling in seconds
    #isStation::Bool #tells if a block is in a station and possibly involves passengers
    tracks::Int # number of parallel tracks (multiple trains allowed)
    nt::Int # number of trains on the block (size of next set)
    train::Set{String} # which train is on it
end

mutable struct Network
    n::Int # number of nodes (Operational Points = Betriebstellen)
    nodes::Dict{String,OPoint} #contains all the ops
    nb::Int # nr of blocks
    blocks::Dict{String,Block} #all the blocks
end
function Network() # default initialization
    Network(0,Dict{String,OPoint}(),0,Dict{String,Block}())
end

# mutable struct Delay # used to keep Transit as immutable
#     delay::Int
# end

struct Transit
    trainid::String # train id going through
    opid::String # Betriebstelle id
    kind::String # Ankunft/Abfahrt/Durchfahrt/Ende
    duetime::Int # due time in seconds from midnight
    #imposed_delay::Delay # forced delay in seconds - used to test robustness
end
# Transit(trainid::String, opid::String7, kind::String15, duetime::Int) =
#     Transit(trainid, opid, kind, duetime); # sets the default imposed delay to zero



mutable struct DynTrain
    #id::String
    n_opoints_visited::Int # tells which was last visited op (points to the schedule)
    currentBlock::String
    nextBlock::String
    #nextBlockDueTime::Int
    #nextBlockRealTime::Int
end

mutable struct Train
    id::String
    schedule::Vector{Transit} # schedule[duetime] = info on stops
    dyn::DynTrain
    delay::Dict{String, Int} # Train[block] = imposed delay for train inblock
end

mutable struct Fleet
    n::Int
    train::Dict{String, Train} # train[trainid]=Train
end

struct RailwayNetwork
    network::Network # the network where trains move
    # trains
end




########################################
##EXCEPTIONS DEFINING
##################################
struct exception_blockConflict <: Exception
        trainid::String
        block::String
    end

Base.showerror(io::IO, e::exception_blockConflict) = print(io, "Train $(e.trainid) has conflict in block $(e.block) ")
