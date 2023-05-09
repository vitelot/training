using Dates
using CSV, DataFrames

function pottendorfer_line(departure_time, speed_reduction=0.8)
    blocks = DataFrame(CSV.File("blocks.csv"))
    filter!(row -> row["line"] == "10601", blocks)

    # Read all the operational points (OPs) along a particular track in a dataframe "block"
    df_op = DataFrame(CSV.File("NB-MI-10601.csv"))
    rename!(df_op, "bst" => "bst1")
    # Create another dataframe in which OPs are shifted by 1
    df_op_shifted = df_op[2:end, :]
    rename!(df_op_shifted, "bst1" => "bst2")
    
    # Now remove the last row of df_op
    df_op = df_op[1:end-1, :]

    # Join the "df_op" and "df_op_shifted" to create blocks
    df = hcat(df_op, df_op_shifted)
    df[!, "block"] = string.(df[!, "bst1"], "-", df[!, "bst2"])
    df[!, "Order"] = range(1, nrow(df))

    # Read max_speeds for all the blocks
    df_speeds = DataFrame(CSV.File("pottendorf_max_speeds.csv", header=["block", "max_speed"]))

    # Intersection of all blocks (blocks) and our blocks (df) to include block length column
    df = innerjoin(blocks, df, on="block")
    #println(df)
    # Interesection with speeds to includes max-speeds column
    println(setdiff(Set(df[!, "block"]), Set(df_speeds[!, "block"])))

    df = innerjoin(df, df_speeds, on="block")
    df = df[sortperm(df[!, "Order"]), :]
    
    df[!, "max_speed"] .*= 5 / 18 # km/hr to m/s
    df[!, "speed"] .= speed_reduction .* df[!, "max_speed"]
    df[!, "time_to_pass"] = Int.(round.(df[!, "length"] ./ df[!, "speed"]))
    df[!, "Arrival_time_at_bst1"] .= departure_time
    df[!, "Departure_time_at_bst1"] .= departure_time
    df[!, "distance"] .= 0

    for ix in 2:nrow(df)
        df[ix, "Arrival_time_at_bst1"] = df[ix-1, "Departure_time_at_bst1"] + df[ix-1, "time_to_pass"]
        df[ix, "Departure_time_at_bst1"] = df[ix, "Arrival_time_at_bst1"] 
        df[ix, "distance"] = df[ix-1, "distance"] + df[ix-1, "length"]
    end

    # Add the last station
    append!(df, DataFrame(bst1 = ["MI"], distance = [df[end, "distance"] + df[end, "length"]], 
           Arrival_time_at_bst1 = [df[end, "Arrival_time_at_bst1"] + df[end, "time_to_pass"]]), 
           cols=:subset)

    # Remove unwanted columns
    select!(df, ["bst1", "block", "length", "distance", "Arrival_time_at_bst1"])
    rename!(df, "bst1" => "bst", "Arrival_time_at_bst1" => "scheduledtime")

    #df[!, "seconds_since_epoch"] = Int.(Dates.datetime2unix.(DateTime.(date, df[!, "time"])))
    #CSV.write("pottendorf.csv", df)
    return df
end
