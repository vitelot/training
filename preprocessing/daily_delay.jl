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

function main()
    DD = Dict{String,Int}()
    TD = Dict{String,Int}()

    df = CSV.File("data.csv") |> DataFrame
    dropmissing!(df, [:realtime, :duetime])

    previousday = ""
    for i = 1:nrow(df)
        day = df.day[i]
        if !haskey(DD, day)
            get!(DD, day, 0)
            if previousday != ""
                DD[previousday] = sum(collect(values(TD)))
                println("# $previousday $(DD[previousday]) $(length(TD))")
            end
            previousday = day
            TD = Dict{String,Int}()
        end
        treno = df.treno[i]
        get!(TD, treno,0)
        TD[treno] = dateToSeconds(df.realtime[i]) - dateToSeconds(df.duetime[i])
    end

    for i in sort(keys(DD))
        println("$i $(DD[i])")
    end
end

main()
