using CSV, DataFrames, Distributions, StatsBase


function pwl()
"""
It extracts a random value from the power law distribution
"""
    return 60*rand(Float64)^(1/(1-2.16))   #60s is the mimimum delay value in the power-law distribution , 2.16 is the exponent
end


function main()
"""
It takes the trains from the timetable, assign to them a probability based on a CSV,
extracts the number n of exo. delays that has to be inserted, extract the BSTs,
build the csv with exo. delays to be assigned
"""
    dft=DataFrame(CSV.File("tipica.csv"))           #Or Mon, Tue, ... Or timetable
    dtrains=unique(dft.trainid)

    dfp=DataFrame(CSV.File("probabilities.csv"))
    dfp=filter(:trainid => x-> x ∈dtrains,dfp)


    d=LogNormal(4.26,0.46)  #Total number of exogeneous delays we inject
    n=round(Int,rand(d))


    dtrains=Vector{String}()
    for i in 1:n
        t=sample(dfp.trainid, StatsBase.Weights(dfp.prob))
        push!(dtrains,t)
    end

    BT=Dict{String,String}()
    for t in dtrains
        df=filter(:trainid => ==(t),dft)
        BT[t]=rand(df.opid)
    end

    bst=[BT[i] for i in dtrains]
    delay=[pwl() for i in 1:n]
    df=DataFrame([dtrains,bst,delay], [:trainid, :opid,:delay])

    CSV.write("exo_delays", df, header=false)
end
