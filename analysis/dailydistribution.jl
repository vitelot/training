using DataFrames, CSV, Dates

function dateToSeconds(d::String)::Int
"""
Given a string in the format "yyyy-mm-dd HH:MM:SS"
returns the number of seconds elapsed from the epoch #midnight
"""
    dt::DateTime = Dates.DateTime(d, "dd.mm.yyyy HH:MM:SS")
    return Dates.value(dt)÷1000
    #return (Dates.hour(dt)*60+Dates.minute(dt))*60+Dates.second(dt)
end

struct Transit
    duetime::Int
    realtime::Int
end

function main()
    Delays = Dict{String,Vector{Float64}}()

    df = CSV.File("data.csv") |> DataFrame
    dropmissing!(df, [:duetime, :realtime])

    dayList = unique(sort(df.day))

    for day in dayList

        Travel = Dict{String,Vector{Transit}}()

        get!(Delays, day, Float64[])

        dfday = df[df.day .== day, :]

        for i = 1:nrow(dfday)
            treno = dfday.treno[i]
            rt = dateToSeconds(dfday.realtime[i])
            dt = dateToSeconds(dfday.duetime[i])
            get!(Travel, treno, Transit[])
            push!(Travel[treno], Transit(dt,rt))
        end

        for treno in keys(Travel)
            journey = Travel[treno]
            l = length(journey)
            if l < 2 continue end

            for i in 1:l-1
                dt = journey[i+1].duetime - journey[i].duetime
                rt = journey[i+1].realtime - journey[i].realtime
                dt > 0 && push!(Delays[day], rt/dt)
            end

        end
    end

    for day in keys(Delays)
        outfile = "$day.dat"
        sort!(Delays[day], rev=true)
        data = DataFrame(delay=Delays[day])
        CSV.write(outfile, data, writeheader=false)
    end

    nothing
end

main()
