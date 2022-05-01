using DataFrames, CSV, Dates

function dateToSeconds(d::String31)::Int
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

struct Transit
    duetime::Int
    realtime::Int
end

function main(file="data.csv")
    # use on the file coming from ./raw2nice.tcsh PAD-Zuglaufdaten_2019-01.csv
    Delays = Dict{String,Vector{Int}}()

    df = CSV.File(file) |> DataFrame
    # rename!(df,:Istzeit => :realtime)
    # rename!(df,:Betriebstag => :day)
    # rename!(df,:Zugnr => :treno)
    # rename!(df,:"Sollzeit R" => :duetime)
    # rename!(df,:"Zuglaufmodus Code" => :code)

    dropmissing!(df, [:duetime, :realtime])

    dayList = unique(df.day)

    for day in dayList

        Travel = Dict{String,Vector{Transit}}()

        get!(Delays, day, Int[])

        dfday = df[df.day .== day, :]

        for i = 1:nrow(dfday)
            train = dfday.train[i] |> string
            rt = dateToSeconds(dfday.realtime[i])
            dt = dateToSeconds(dfday.duetime[i])
            get!(Travel, train, Transit[])
            push!(Travel[train], Transit(dt,rt))
        end

        for train in keys(Travel)

            journey = sort(Travel[train], by=x->x.duetime)
            l = length(journey)
            if l < 2 continue end


            # for i in 1:l-1
            #     dt = journey[i+1].duetime - journey[i].duetime
            #     rt = journey[i+1].realtime - journey[i].realtime
            #     dt > 0 && push!(Delays[day], rt/dt)
            # end

            delay = journey[end].realtime-journey[end].duetime
            push!(Delays[day], delay)
        end
    end

    for day in keys(Delays)
        outfile = "$day.dat"
        sort!(Delays[day], rev=true)
        data = DataFrame(delay=Delays[day])
        CSV.write(outfile, data, header=false)
    end

    nothing
end

main()
