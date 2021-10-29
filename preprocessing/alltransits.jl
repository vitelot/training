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
    bs::String
    duetime::Int
    realtime::Int
end

function main()
    Delays = Dict{String,Vector{Float64}}()

    df = CSV.File("data.csv") |> DataFrame
    dropmissing!(df, [:duetime, :realtime])
    # allowmissing!(df)
    # df .= ifelse.(ismissing.(df), "XXXXXX", df)

    dayList = unique(df.day)

    for day in dayList
        outfile = "$day.dat"
        println(day)

        Travel = Dict{String,Vector{Transit}}()

        get!(Delays, day, Float64[])

        dfday = df[df.day .== day, :]

        for i = 1:nrow(dfday)
            treno = dfday.treno[i]
            # println(dfday[i, :])
            # if ismissing(dfday.bscode)
            # end
            bs = coalesce(dfday.bscode[i],"XXXXXX") #ismissing(dfday.bscode) ? "XXXXXX" : dfday.bscode
            rt = dateToSeconds(dfday.realtime[i])
            dt = dateToSeconds(dfday.duetime[i])
            get!(Travel, treno, Transit[])
            push!(Travel[treno], Transit(bs,dt,rt))
        end

        OUT = open(outfile, "w")
        for treno in keys(Travel)
            journey = Travel[treno]
            l = length(journey)
            if l < 2 continue end

            for i in 1:l-1
                blk = journey[i].bs * "," * journey[i+1].bs
                dt = journey[i+1].duetime - journey[i].duetime
                rt = journey[i+1].realtime - journey[i].realtime
                println(OUT, "$day,$treno,$blk,$dt,$rt,$(round(rt/dt, digits=3))")
            end

        end
        close(OUT)
    end

    nothing
end

main()

# Problems
# 04.02.19,R2212,HET,Abfahrt,04.02.2019 08:09:30,04.02.2019 08:14:04
# 04.02.19,R2212,HET,Ankunft,04.02.2019 08:09:30,04.02.2019 08:13:42
#
# 04.02.19,R22342,BU,Ankunft,04.02.2019 08:12:54,04.02.2019 08:14:03
# 04.02.19,R22342,BU,Abfahrt,04.02.2019 08:13:24,04.02.2019 08:14:04
