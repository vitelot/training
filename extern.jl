"""
This file contains the definition of data structures,
useful shortcuts,
and the packages to be loaded
"""

using DataFrames, CSV

Double = Float64

struct Block
    id::String #each block has got its own name
    idx::Int # and number
    minT::Int #minimum time of block travelling in seconds
    dueT::Int #due time of travelling in seconds
    parent::Vector{Int} #parent blocks where trains come from
    child::Vector{Int} #child blocks where trains go to
    isStation::Bool #tells if a block is in a station and possibly involves passengers
end

mutable struct Network
    nBlocks::Int # number of blocks
    blocks::Vector{Block} #contains all the blocks
    IDtoIDX::Dict{String,Int} #translates block IDs into array ids
end
function Network() # default initialization
    Network(0,Vector{Block}[],Dict{String,Int}())
end


struct RailwayNetwork
    network::Network # the network where trains move
    # trains
end
