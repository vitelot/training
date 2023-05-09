using CSV, DataFrames

include("construct_pottendorfer_line.jl")

function reroute!()


end

function main(timetable="timetable.csv", trainid="RJ_130")
    df = DataFrame(CSV.File(timetable))
    filter!(row -> row["trainid"] == trainid, df)
    #filter!(row -> row["bst"] in ["NB", "MI"], df)
    #println(df)
    
    # Altenate route
    #df_alter = DataFrame(CSV.File("pottendorf.csv"))

    # Locate all the rows for a given trainid whose bst is between NB and MI
    # First locate the rows corresponding to NB and MI
    NB_rows = findall(df[!, "bst"] .== "NB")
    MI_rows = findall(df[!, "bst"] .== "MI")

    # If the train stops at NB and MI, there are two rows corresponding to each of these
    # One row for arrival, another for departure. Pick the second (departure) row of NB
    # and arrival row of MI, and change the rows between these two
    row_start = NB_rows[2] + 1
    row_end = MI_rows[1]-1

    #println(df[row_start:row_end, :])
    df_upto_NB = df[1:NB_rows[2], :]
    df_after_MI = df[MI_rows[2]:end, :]

    arrival_time_at_NB = df[NB_rows[1], "scheduledtime"]
    departure_time_at_NB = df[NB_rows[2], "scheduledtime"]
    df_pottendorfer = pottendorfer_line(departure_time_at_NB)
    df_pottendorfer[!, "trainid"] .= trainid
    df_pottendorfer[!, "transittype"] .= "p"
    df_pottendorfer[!, "direction"] .= "2"
    df_pottendorfer[!, "line"] .= "10601"

    select!(df_pottendorfer, ["trainid", "bst", "transittype", "direction", "line", "distance", "scheduledtime"])
    #println(df_pottendorfer)
    #if length(NB_rows)
    #println(first(df, 5))
end

main()
