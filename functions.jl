function dateToSeconds(d::String)
"""
Given a string in the format "yyyy-mm-dd HH:MM:SS"
returns the number of seconds elapsed from midnight
"""
    dt=Dates.DateTime(d, "dd.mm.yyyy HH:MM:SS")
    return (Dates.hour(dt)*60+Dates.minute(dt))*60+Dates.second(dt)
end

function generateTimetable(fl::Fleet)
    TB = TimeTable(0, Dict{Int,Vector{Transit}}())

    println("Generating the timetable")

    for trainid in keys(fl.train)
        println("\tTrain $trainid")
        for duetime in keys(fl.train[trainid].schedule)
            TB.n += 1
            get!(TB.timemap, duetime, Transit[])
            push!(TB.timemap[duetime], fl.train[trainid].schedule[duetime])

        end
    end
    # passed by reference: TB.timemap[21162][1]===FL.train["REX7104"].schedule[21162] -> true

    println("Timetable generated with $(TB.n) events")
    TB
end
