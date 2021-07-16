"""
This file contains the definition of data structures,
useful shortcuts,
and the packages to be loaded
"""

using DataFrames, CSV

Double = Float64

struct Block
    id::Int #each block has got its own id number
    minT::Int #minimum time of block travelling in seconds
    dueT::Int #due time of travelling in seconds
    parent::Vector{Int} #parent blocks where trains come from
    child::Vector{Int} #child blocks where trains go to
    isStation::Bool #tells if a block is in a station and possibly involves passengers
end

mutable struct Network
    nBlocks::Int # number of blocks
    blocks::Vector{Block}
end

struct RailwayNetwork
    network::Network # the network where trains move
    # trains
end
