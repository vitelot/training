using DataFrames 

function reroute!(dfout::DataFrame; trainid::String="RJ_130")
    println(first(dfout, 5))
    CSV.write("dfout.csv", dfout)
end
