"""
This file contains the definition of data structures,
useful shortcuts,
and the packages to be loaded
"""

using DataFrames, CSV;
# using Dates;
# using StatsBase;
using PrettyPrint;
# using Profile
# using InteractiveUtils
import Base.show;

###################################
###       Global variables      ###
ProgramVersion = v"0.5.0";
Opt = Dict{String,Any}(); # options read from par.ini
###################################

#struct not used for now
# struct OPoint # Operational Point: Betriebstelle
#     id::String # id name
#     idx::Int # numerical index
#     lat::Float64
#     long::Float64
#     parent::Vector{String}
#     child::Vector{String}
#     isStation::Bool
# end

# a SuperBlock is a set of consecutive blocks with one track used in both directions that allow one train only
# a non positive id means that the block/station coincides with a block
mutable struct SuperBlock
    id::Int
    isempty::Bool
    trainid::String # the train on it
end

function SuperBlock(id::Int)
    SuperBlock(id, true, "") # set up a default free superblock with an id
end

mutable struct Station
    id::String          # each station has got its own name
    # line::String        # the line a block is serving
    # isStation::Bool     # tells if a block is in a station and possibly involves passengers; it can be a junction otherwise
    # length::Int         # length in meters
    # direction::Int      # can be 1 or 2 (e.g., 1=north 2=south)
    platforms::Dict{Int,Int} # number of platforms per direction key=direction, value=nrtracks
    sidings::Int          # not used for the moment
    
    # dynamical part:
    # nt::Dict{Int,Int}     # number of trains in the station according to direction 
    train::Dict{Int,Set{String}}    # which train is on a direction
    sblock::SuperBlock       # superblock it belongs to
end

function Station()
    Station("",Dict{Int,Int}(),0,Dict{Int,Set{String}}(),SuperBlock(0)); #the null empty station
end

mutable struct Block
    id::String          # each block has got its own name
    line::String        # the line a block is serving
    length::Int         # length in meters
    direction::Int      # can be 1 or 2 (e.g., 1=north 2=south)
    tracks::Int         # number of parallel tracks (multiple trains allowed)
    # dynamical part:
    nt::Int             # number of trains on the block (size of next set)
    train::Set{String}  # which train is on it, for platforms: which train is in which of the directions
    sblock::SuperBlock  # superblock it belongs to
end

function Block()
    Block("","",0,0,0,0,Set{String}(),SuperBlock(0)); #the null empty block
end

mutable struct Network
    ns::Int # number of stations (Operational Points = Betriebstellen)
    stations::Dict{String,Station} #contains all the ops with many tracks, platforms
    nb::Int # nr of blocks
    blocks::Dict{String,Block} #all the blocks
    superblocks::Dict{Int,SuperBlock} # all the superblocks
end

function Network() # default initialization
    Network(0,Dict{String,Station}(),0,Dict{String,Block}(),Dict{Int,SuperBlock}())
end

# mutable struct Delay # used to keep Transit as immutable
#     delay::Int
# end

struct Transit
    trainid::String     # train id going through
    opid::String        # Operational point id
    kind::String        # Type of event: Arrival/Departure/Pass/End/Begin
    line::String        # the line the train is serving
    direction::Int      # its direction (1 or 2)
    duetime::Int        # due time in seconds from midnight
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
    #line::String # track id in whih the train runs
    #direction::Int# direction wrt the origin of the track
    dependence::String # id of train that has to arrive at final destination before this train starts
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
## Define the exception for an occupied block
## to use in the try and catch
##################################
struct exception_blockConflict <: Exception
    trainid::String
    block::String
    direction::Int
end
##################################

Base.showerror(io::IO, e::exception_blockConflict) =
    print(io, "Train $(e.trainid) has conflict in block $(e.block) ");

function show(io::IO, D::Dict{Int64, Set{String}})
    for (k,v) in D
        print(io, "$k:(");
        for i in v
            print(io, "$i,");
        end
        print(io, ") ");
    end
    # println();
end