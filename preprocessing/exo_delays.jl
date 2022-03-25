using CSV, DataFrames, Distributions, StatsBase


function pwl()
"""
It extracts a random value from the power law distribution
"""
    d=60*rand(Float64)^(1/(1-2.5))   #60s is the mimimum delay value in the power-law distribution , 2.16 is the exponent
    return round(Int64, d)
end


function main()
"""
It takes the trains from the timetable, assign to them a probability based on a CSV,
extracts the number n of exo. delays that has to be inserted, extract the BSTs,
build the csv with exo. delays to be assigned
"""
    dft=DataFrame(CSV.File("tipicaok.csv"))           #Or Mon, Tue, ... Or timetable
    dtrains=unique(dft.trainid)

    dfp=DataFrame(CSV.File("probabilities.csv"))
    dfp=filter(:trainid => x-> x ∈dtrains,dfp)


    d=LogNormal(4.26,0.46)
    n=round(Int,rand(d))              #Total number of exogeneous delays we inject

    sample_rows = sample(1:nrow(dfp), StatsBase.Weights(dfp.prob), n)  #It samples n rows based on their probabilities
    dfp = dfp[sample_rows, :]

    dfp[!,:delay] = [pwl() for i in 1:n]        # This adds the column of n random delays

    dfp=select!(dfp, Not(:prob))


    CSV.write("exo_delays", dfp, header=false)
end
