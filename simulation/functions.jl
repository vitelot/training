
"""
functions.jl : contains the definition of functions that are NOT needed for initializing our system on the infrastructure
"""

function dateToSeconds(d::AbstractString)::Int
"""
Given a string in the format "yyyy-mm-dd HH:MM:SS"
returns the number of seconds elapsed from the epoch
"""
    dt::DateTime = Dates.DateTime(d, "dd.mm.yyyy HH:MM:SS")
    return Int(floor(datetime2unix(dt)))
    #return (Dates.hour(dt)*60+Dates.minute(dt))*60+Dates.second(dt)
end
function dateToSeconds(d::Int)::Int
"""
If the input is an Int do nothing
assuming that it is already the number of seconds elapsed from the epoch
"""
    return d
end

############################################################################################################
function read_non_hidden_files(repo::AbstractString)::Vector{String}
    filelist = readdir(repo, join=true);
    filter!(!isdir, filelist);
    filelist = basename.(filelist);

    # ignore files starting with . and _
    return filter(x->!startswith(x, r"\.|_"), filelist)
end

function runTest(RN::Network, FL::Fleet)
    """If test mode is enabled, runs speed test without printing simulation results on std out
    """

#    print("\nPerforming speed test with no output. Please be patient.\r")
    # if Opt["test"] == 2
    #     print("Using @btime ...\r")
    #     @btime simulation($RN, $FL)
    # else
        @time simulation(RN, FL)
        print("Macro @time was used.\n")
    # end
end

function myRand(min::Float64, max::Float64)::Float64
    """ranged random number generator"""
    return rand(range(min,length=20,stop=max))
end

function netStatus(S::Set{String}, BK::Dict{String,Block}; hashing::Bool=false)

    """function that calculates the status of the simulation as a string of blocks
     and their occupancies in terms of train id;
     has also a hashing function to try to speed up
    """
    if isempty(S)
        println("in netstatus S is empty")
        return ""
    end

    status = "";
    for blk_id in sort(collect(keys(BK))) # we might need a sort here because the order of keys may change
        blk = BK[blk_id];
        if isa(blk.nt, Int)
            if blk.nt > 0
                status *= "$(blk_id):$(blk.train) ";
            end
        else
            status *= "$(blk_id):$(blk.train) ";

        end
    end

    #status *= "\n$S";

    #hashing && return sha256(status) |> bytes2hex; #sha256()->hexadecimal; bytes2hex(sha256())->string
    hashing && return hash(status);

    return status
end

function resetSimulation(FL::Fleet)#,RN::Network
"""
Resets the dynamical variables of trains in case of multiple simulation runs
"""
    #println("resetting Fleet")
    for Train in values(FL.train)
        Train.dyn = DynTrain(0,"","");
    end
end

import Base.sort!
sort!(v::Vector{Transit}) = sort!(v, by=x->x.duetime) # usage: FL.train["SB29541"].schedule

import Base.issorted
issorted(v::Vector{Transit}) = issorted(v, by=x->x.duetime) # usage: FL.train["SB29541"].schedule
