using CSV, DataFrames

include("parser.jl");
parsed_args = parse_commandline()

source_path::String   = parsed_args["source_data_path"]
# Actually, target_path is also a source path for functions in this file
target_path::String   = parsed_args["target_data_path"]

function pottendorfer_schedule(departure_time, speed_reduction=0.66)::DataFrame
    blocks = DataFrame(CSV.File(joinpath(target_path, "blocks.csv")))
    filter!(row -> row[:line] == "10601", blocks)

    # Read all the operational points (OPs) along a particular track in a dataframe "block"
    df_op = DataFrame(CSV.File(joinpath(source_path, "Lines/NB-MI-10601.csv")))
    rename!(df_op, :bst => :bst1)
    # Create another dataframe in which OPs are shifted by 1
    df_op_shifted = df_op[2:end, :]
    rename!(df_op_shifted, :bst1 => :bst2)
    
    # Now remove the last row of df_op
    df_op = df_op[1:end-1, :]

    # Join the "df_op" and "df_op_shifted" to create blocks
    df = hcat(df_op, df_op_shifted)
    df[!, "block"] = string.(df[!, :bst1], "-", df[!, :bst2])
    df[!, "Order"] = range(1, nrow(df))

    # Read max_speeds for all the blocks
    df_speeds = DataFrame(CSV.File(joinpath(source_path, "pottendorfer_max_speeds.csv"), 
                                   header=[:block, :max_speed]))

    # Intersection of all blocks (blocks) and our blocks (df) to include block length column
    df = innerjoin(blocks, df, on=:block)
    # Find out the blocks for which max-speed is not available, and assign max-speed to them
    df_rinf_ops = DataFrame(CSV.File(joinpath(source_path, "rinf_ops.csv"), header=[:op_name]))
    missing_ops_nbrs = Dict{String, Vector{String}}()
    # Here we iterate over all the blocks which are not in df_speeds
    for val in setdiff(Set(df[!, :block]), Set(df_speeds[!, :block]))
        (op1, op2) = split(val, "-")
        if !(op1 in df_rinf_ops[!, :op_name])
            get!(missing_ops_nbrs, op1, [])
            push!(missing_ops_nbrs[op1], op2)
        elseif !(op2 in df_rinf_ops[!, :op_name])
            get!(missing_ops_nbrs, op2, [])
            push!(missing_ops_nbrs[op2], op1)
        end
    end
    # Create joint blocks for which max-speeds are available
    for key in keys(missing_ops_nbrs)
        joint_block = string(missing_ops_nbrs[key][1],"-",missing_ops_nbrs[key][2])
        joint_block_max_speed = df_speeds[findall(df_speeds[!, :block] .== joint_block), :max_speed][1]
        # Assign this max_speed of joint block to two individual blocks in 
        # each direction (total four blocks)
        block1 = string(key,"-",missing_ops_nbrs[key][1])
        block2 = string(key,"-",missing_ops_nbrs[key][2])
        block3 = string(missing_ops_nbrs[key][1],"-",key)
        block4 = string(missing_ops_nbrs[key][2],"-",key)
        push!(df_speeds, [block1, joint_block_max_speed])
        push!(df_speeds, [block2, joint_block_max_speed])
        push!(df_speeds, [block3, joint_block_max_speed])
        push!(df_speeds, [block4, joint_block_max_speed])
    end
    # Interesection with speeds to includes max-speeds column
    df = innerjoin(df, df_speeds, on=:block)
    df = df[sortperm(df[!, :Order]), :]
    
    df[!, :max_speed] .*= 5 / 18 # km/hr to m/s
    df[!, :speed] .= speed_reduction .* df[!, :max_speed]
    df[!, :time_to_pass] = Int.(round.(df[!, :length] ./ df[!, :speed]))
    df[!, :Arrival_time_at_bst1] .= departure_time # There is no typo on this line!
    df[!, :Departure_time_at_bst1] .= departure_time
    df[!, :distance] .= 0

    for ix in 2:nrow(df)
        df[ix, :Arrival_time_at_bst1] = df[ix-1, :Departure_time_at_bst1] + df[ix-1, :time_to_pass]
        df[ix, :Departure_time_at_bst1] = df[ix, :Arrival_time_at_bst1] 
        df[ix, :distance] = df[ix-1, :distance] + df[ix-1, :length]
    end

    # Add the last station
    append!(df, DataFrame(bst1 = ["MI"], distance = [df[end, :distance] + df[end, :length]], 
           Arrival_time_at_bst1 = [df[end, :Arrival_time_at_bst1] + df[end, :time_to_pass]]), 
           cols=:subset)

    # Remove unwanted columns
    select!(df, [:bst1, :distance, :Arrival_time_at_bst1])
    rename!(df, :bst1 => :bst, :Arrival_time_at_bst1 => :scheduledtime)

    return df
end

function reroute_sudbahn_to_pottendorfer!(df_full; trainid="RJ_130")


    # Extract sub-dataframe corresponding to the given trainid
    df = filter(row -> row[:trainid] == trainid, df_full)

    # Locate all the rows for a given trainid whose bst is between NB and MI
    # First locate the rows corresponding to NB and MI
    NB_rows = findall(df[!, :bst] .== "NB")
    MI_rows = findall(df[!, :bst] .== "MI")

    #=
     If the train stops at NB and MI, there are two rows corresponding to each of these
     One row for arrival, another for departure. Pick the second (departure) row of NB
     and arrival row of MI, and change the rows between these two. If the train starts 
     at NB, there would be only one corresponding row, choose the only element
    =#
    if length(NB_rows) == 2
        row_start = NB_rows[2] + 1
        df_upto_NB = df[1:NB_rows[1], :]
    else
        row_start = NB_rows[1] + 1
        df_upto_NB = DataFrame()
    end
    row_end = MI_rows[1]-1

    if length(MI_rows) == 2
        df_after_MI = df[MI_rows[2]:end, :]
    else
        #df_after_MI = df[MI_rows[1]:end, :]
        df_after_MI = DataFrame()
    end
    # We need block_length column in df_after_MI to adjust distance column
    # after rerouting
    if nrow(df_after_MI) > 0
        df_after_MI[!, :block_length] .= df_after_MI[!, :distance] .- df_after_MI[1, :distance]
    end
    # We also need the duration for which the train stops at MI
    if length(MI_rows) == 2
        stopping_duration_at_MI = df[MI_rows[2], :scheduledtime]-df[MI_rows[1], :scheduledtime]
    else
        stopping_duration_at_MI = 0
    end
    # We also need scheduled time to reach each further block after exiting MI
    if nrow(df_after_MI) > 0
        df_after_MI[!, :block_reach_time] .= df_after_MI[!, :scheduledtime] .- df_after_MI[1, :scheduledtime]
    end

    # Get the schedule along the alternate Pottendorfer Linie
    if length(NB_rows) == 2
        departure_time_at_NB = df[NB_rows[2], :scheduledtime]
    else
        departure_time_at_NB = df[NB_rows[1], :scheduledtime]
    end
    df_pottendorfer = pottendorfer_schedule(departure_time_at_NB)
    df_pottendorfer[!, :trainid] .= trainid
    df_pottendorfer[!, :transittype] .= "p"
    if length(NB_rows) == 2
        df_pottendorfer[1, :transittype] = "d"
    else
        df_pottendorfer[1, :transittype] = "b"
    end
    if length(MI_rows)== 2
        df_pottendorfer[end, :transittype] = "a"
    elseif length(MI_rows)== 1
        df_pottendorfer[end, :transittype] = "e"
    end
    df_pottendorfer[!, :direction] .= 2
    df_pottendorfer[!, :line] .= 10601

    select!(df_pottendorfer, [:trainid, :bst, :transittype, :direction, 
                              :line, :distance, :scheduledtime])

    # Now correct the distance along Pottendorfer by adding distance covered
    # upto NB
    if nrow(df_upto_NB) > 0
        df_pottendorfer[!, :distance] .+= df_upto_NB[end, :distance]
    end
    println(first(df_pottendorfer, 5))
    if nrow(df_after_MI) > 0
        # Correct the scheduledtime along Sudbahn after exiting MI 
        df_after_MI[!, :scheduledtime] = df_pottendorfer[end, :scheduledtime] .+ df_after_MI[!, :block_reach_time] 
        # We should correct this scheduledtime further by adding stopping duration at MI
        df_after_MI[!, :scheduledtime] .+= stopping_duration_at_MI 
        # Finally, correct the distance along Sudbahn after exiting MI
        df_after_MI[!, :distance] .= df_after_MI[!, :block_length] .+ df_pottendorfer[end, :distance]
        select!(df_after_MI, Not([:block_length, :block_reach_time]))
    end
    append!(df_upto_NB, df_pottendorfer, cols=:setequal, promote=true)
    append!(df_upto_NB, df_after_MI, cols=:setequal, promote=true) # df_upto_NB now contains all the data up to the last station
    empty!(df)
    df = df_upto_NB
    df_upto_NB = Nothing

    # Now replace the part of the full schedule by the rerouted schedule 
    trainid_start_ix = findall(df_full[!, :trainid] .== trainid)[1]
    trainid_end_ix = findall(df_full[!, :trainid] .== trainid)[end]
    #df_full = vcat(df_full[1:trainid_start_ix-1, :], df, df_full[trainid_end_ix+1:end, :])
    filter!(row -> row[:trainid] .!= trainid, df_full)
    append!(df_full, df, promote=true)
    sort!(df_full, :trainid)
    #return df_full
end
