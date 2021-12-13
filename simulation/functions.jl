function dateToSeconds(d::String31)::Int
"""
Given a string in the format "yyyy-mm-dd HH:MM:SS"
returns the number of seconds elapsed from the epoch
"""
    dt::DateTime = Dates.DateTime(d, "dd.mm.yyyy HH:MM:SS")
    return Dates.value(dt)÷1000
    #return (Dates.hour(dt)*60+Dates.minute(dt))*60+Dates.second(dt)
end
function dateToSeconds(d::Int)::Int
"""
If the input is an Int do nothing
assuming that it is already the number of seconds elapsed from the epoch
"""
    return d
end

# function printDebug(lvl::Int, s...)
#     if lvl == 0
#         return;
#     elseif lvl == 1
#         println(s...); return;
#     elseif lvl <= 2
#         println(s...); return;
#     else
#         return;
#     end
# end

function generateTimetable(fl::Fleet)::TimeTable
    Opt["print_flow"] && println("Generating the timetable")
    print_train_list = Opt["print_train_list"]

    TB = TimeTable(0, Dict{Int,Vector{Transit}}())

    for trainid in keys(fl.train)
        print_train_list && println("\tTrain $trainid")
        for s in fl.train[trainid].schedule
            TB.n += 1
            duetime = s.duetime
            get!(TB.timemap, duetime, Transit[])
            push!(TB.timemap[duetime], s)

        end
    end
    # passed by reference: TB.timemap[21162][1]===FL.train["REX7104"].schedule[21162] -> true

    Opt["print_flow"] && println("Timetable generated with $(TB.n) events")
    TB
end

function runTest(RN::Network, FL::Fleet)

#    print("\nPerforming speed test with no output. Please be patient.\r")
    if Opt["TEST"] == 2
        print("Using @btime ...\r")
        @btime simulation($RN, $FL)
    # elseif Opt["TEST"] == 3
    #     @benchmark simulation($RN, $FL)
    else
        @time simulation(RN, FL)
        print("Macro @time was used.\n")
    end
end

function myRand(min::Float64, max::Float64)::Float64

    return rand(range(min,length=20,stop=max))
end

function netStatus(S::Set{String}, BK::Dict{String,Block}; sha::Bool=false)
    status = "";
    for blk_id in keys(BK) # we might need a sort here because the order of keys may change
        blk = BK[blk_id];
        if blk.nt > 0
            status *= "$(blk_id):$(blk.train) ";
        end
    end

    status *= "\n$S";

    sha && return sha256(status) |> bytes2hex;

    return status
end
