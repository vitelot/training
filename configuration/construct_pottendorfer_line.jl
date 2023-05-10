using Dates
using CSV, DataFrames

function pottendorfer_line(departure_time, speed_reduction=0.8)
    blocks = DataFrame(CSV.File("blocks.csv"))
    filter!(row -> row[:line] == "10601", blocks)

    # Read all the operational points (OPs) along a particular track in a dataframe "block"
    df_op = DataFrame(CSV.File("NB-MI-10601.csv"))
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
    df_speeds = DataFrame(CSV.File("pottendorfer_max_speeds.csv", header=[:block, :max_speed]))

    # Intersection of all blocks (blocks) and our blocks (df) to include block length column
    df = innerjoin(blocks, df, on=:block)
    # Find out the blocks for which max-speed is not available, and assign max-speed to them
    df_rinf_ops = DataFrame(CSV.File("rinf_ops.csv", header=[:op_name]))
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

#df = pottendorfer_line(1525907100)
#println(df)
