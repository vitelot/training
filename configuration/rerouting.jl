using CSV, DataFrames

include("construct_pottendorfer_line.jl")

function main(timetable="timetable.csv", trainid="RJ_130")
    df = DataFrame(CSV.File(timetable))
    filter!(row -> row[:trainid] == trainid, df)

    # Locate all the rows for a given trainid whose bst is between NB and MI
    # First locate the rows corresponding to NB and MI
    NB_rows = findall(df[!, :bst] .== "NB")
    MI_rows = findall(df[!, :bst] .== "MI")

    #=
     If the train stops at NB and MI, there are two rows corresponding to each of these
     One row for arrival, another for departure. Pick the second (departure) row of NB
     and arrival row of MI, and change the rows between these two
    =#
    row_start = NB_rows[2] + 1
    row_end = MI_rows[1]-1

    df_upto_NB = df[1:NB_rows[1], :]
    df_after_MI = df[MI_rows[2]:end, :]
    # We need block_length column in df_after_MI to adjust distance column
    # after rerouting
    df_after_MI[!, :block_length] .= df_after_MI[!, :distance] .- df_after_MI[1, :distance]
    # We also need the duration for which the train stops at MI
    stopping_duration_at_MI = df[MI_rows[2], :scheduledtime]-df[MI_rows[1], :scheduledtime]
    # We also need scheduled time to reach each further block after exiting MI
    df_after_MI[!, :block_reach_time] .= df_after_MI[!, :scheduledtime] .- df_after_MI[1, :scheduledtime]

    # Get the schedule along the alternate Pottendorfer Linie
    departure_time_at_NB = df[NB_rows[2], :scheduledtime]
    df_pottendorfer = pottendorfer_line(departure_time_at_NB)
    df_pottendorfer[!, :trainid] .= trainid
    df_pottendorfer[!, :transittype] .= "p"
    df_pottendorfer[1, :transittype] = "d"
    df_pottendorfer[end, :transittype] = "a"
    df_pottendorfer[!, :direction] .= 2
    df_pottendorfer[!, :line] .= "10601"

    select!(df_pottendorfer, [:trainid, :bst, :transittype, :direction, 
                              :line, :distance, :scheduledtime])

    # Now correct the distance along Pottendorfer by adding distance covered
    # upto NB
    df_pottendorfer[!, :distance] .+= df_upto_NB[end, :distance]
    # Correct the scheduledtime along Sudbahn after exiting MI 
    df_after_MI[!, :scheduledtime] = df_pottendorfer[end, :scheduledtime] .+ df_after_MI[!, :block_reach_time] 
    # We should correct this scheduledtime further by adding stopping duration at MI
    df_after_MI[!, :scheduledtime] .+= stopping_duration_at_MI 
    # Finally, correct the distance along Sudbahn after exiting MI
    df_after_MI[!, :distance] .= df_after_MI[!, :block_length] .+ df_pottendorfer[end, :distance]
    select!(df_after_MI, Not([:block_length, :block_reach_time]))
    append!(df_upto_NB, df_pottendorfer, cols=:setequal, promote=true)
    append!(df_upto_NB, df_after_MI, cols=:setequal)
    CSV.write("timetable-$(trainid)-rerouted.csv", df_upto_NB)
end

main()
