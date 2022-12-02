
"""
functions.jl : contains the definition of functions that are NOT needed for initializing our system on the infrastructure
"""

function read_non_hidden_files(repo::AbstractString)::Vector{String}
    filelist = readdir(repo, join=true);
    filter!(!isdir, filelist);
    filelist = basename.(filelist);

    # ignore files starting with . and _
    return filter(x->!startswith(x, r"\.|_"), filelist)
end

"""
If test mode is enabled, runs speed test without printing simulation results on std out
"""
function runTest(RN::Network, FL::Fleet)

#    print("\nPerforming speed test with no output. Please be patient.\r")
    # if Opt["test"] == 2
    #     print("Using @btime ...\r")
    #     @btime simulation($RN, $FL)
    # else
        @time simulation(RN, FL)
        print("Macro @time was used.\n")
    # end
end

# """ranged random number generator"""
# function myRand(min::Float64, max::Float64)::Float64
#     return rand(range(min,length=20,stop=max))
# end

"""
 function that calculates the status of the simulation as a string of blocks
 and their occupancies in terms of train id;
 has also a hashing function to try to speed up
"""
function netStatus(RN::Network; hashing::Bool=false)

    BK = RN.blocks;
    ST = RN.stations;

    status = "";
    for blk in values(BK) # we might need a sort here because the order of keys may change
        status *= "$(blk.id):$(blk.train)\n\n";
    end
    status *= "###############################\n\n";
    for station in values(ST) # we might need a sort here because the order of keys may change
        status *= "$(station.id):$(station.train)\n\n";
    end

    #hashing && return sha256(status) |> bytes2hex; #sha256()->hexadecimal; bytes2hex(sha256())->string
    hashing && return hash(status);

    return status
end

"""
Resets the dynamical variables of trains in case of multiple simulation runs
"""
function resetSimulation(FL::Fleet)#,RN::Network
    Opt["print_flow"] && @info "Resetting Fleet dynamical properties before restarting."
    for Train in values(FL.train)
        Train.dyn = DynTrain(0,"","");
    end
end

import Base.sort!
sort!(v::Vector{Transit}) = sort!(v, by=x->x.duetime) # usage: FL.train["SB29541"].schedule

import Base.issorted
issorted(v::Vector{Transit}) = issorted(v, by=x->x.duetime) # usage: FL.train["SB29541"].schedule
