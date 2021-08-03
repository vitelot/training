function dateToSeconds(d::String)
"""
Given a string in the format "yyyy-mm-dd HH:MM:SS"
returns the number of seconds elapsed from the epoch #midnight
"""
    dt=Dates.DateTime(d, "dd.mm.yyyy HH:MM:SS")
    return Dates.value(dt)÷1000
    #return (Dates.hour(dt)*60+Dates.minute(dt))*60+Dates.second(dt)
end

function printDebug(lvl::Int, s...)
    if lvl == 0
        return;
    elseif lvl == 1
        println(s...); return;
    elseif lvl <= 2
        println(s...); return;
    else
        return;
    end
end

function generateTimetable(fl::Fleet)
    println("Generating the timetable")

    TB = TimeTable(0, Dict{Int,Vector{Transit}}())

    for trainid in keys(fl.train)
        println("\tTrain $trainid")
        for s in fl.train[trainid].schedule
            TB.n += 1
            duetime = s.duetime
            get!(TB.timemap, duetime, Transit[])
            push!(TB.timemap[duetime], s)

        end
    end
    # passed by reference: TB.timemap[21162][1]===FL.train["REX7104"].schedule[21162] -> true

    println("Timetable generated with $(TB.n) events")
    TB
end

function myRand()::Double
    return 1.0;
    return rand(0.95:0.01:1.1)
end
