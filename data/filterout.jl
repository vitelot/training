using DataFrames, CSV

function run()
    df  = CSV.File("list of problematic trains") |> DataFrame
    S = Set{String}()

    for i = 1:nrow(df)
        # build the set of excluded trains
        push!(S, df.train[i])
    end

    df  = CSV.File("04.02.19.csv") |> DataFrame

    df2 = filter(row -> row.trainid ∉ S, df)

    CSV.write("04.02.19-filtered.csv", df2)

end

run()
