"""
This file contains the definition of data structures,
useful shortcuts,
and the packages to be loaded
"""

using DataFrames, CSV, Dates

Double = Float64

struct OPoint # Operational Point: Betriebstelle
    id::String # id name
    idx::Int # numerical index
    lat::Double
    long::Double
    parent::Vector{String}
    child::Vector{String}
end

struct Block
    id::String #each block has got its own name
    idx::Int # and number
    minT::Int #minimum time of block travelling in seconds
    dueT::Int #due time of travelling in seconds
    # parent::Vector{Int} #parent blocks where trains come from
    # child::Vector{Int} #child blocks where trains go to
    isStation::Bool #tells if a block is in a station and possibly involves passengers
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


struct RailwayNetwork
    network::Network # the network where trains move
    # trains
end


struct Transit
    trainid::String # train id going through
    opid::String # Betriebstelle id
    kind::String # Ankunft/Abfahrt/Durchfahrt/Ende
    duetime::Int # due time in seconds from midnight
end

mutable struct TimeTable
    n::Int # dimension of vector below
    #list::Vector{Transit}
    timemap::Dict{Int,Transit}
end

struct sTransit
    opid::String # Betriebstelle id
    kind::String # Ankunft/Abfahrt/Durchfahrt/Ende
end

mutable struct Train
    id::String
    schedule::Dict{Int,sTransit} # schedule[duetime] = info on stops
end

mutable struct Fleet
    n::Int
    train::Dict{String, Train} # train[trainid]=Train
end
