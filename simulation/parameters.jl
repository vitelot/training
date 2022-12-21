"""
This file contains the functions to load the simulation options from
/data/simulation_data/par.ini
If not existing, creates one as default
"""
function loadOptions(parsed_args::Dict)

    file                        = parsed_args["ini"]

    Opt["test"]                 = parsed_args["speed_test"]
    Opt["catch_conflict"]       = parsed_args["catch_conflict"]
    Opt["inject_delays"]        = parsed_args["inject_delays"]
    Opt["multi_simulation"]     = parsed_args["multi_simulation"]

    if !isfile(file)
        createIniFile(file)
    end


    for line in eachline(file)
        occursin(r"^#", line) && continue # ignore lines beginning with #
        df = split(line, r"\s+")
        length(df) < 2 && continue # ignore empty lines
        key = df[1] ; val = df[2]
        ####################################################################
        if(key=="Version")                  Opt[key] = val
        ####################################################################
        elseif(key=="block_file")           Opt[key] = val
        elseif(key=="timetable_file")       Opt[key] = val
        elseif(key=="station_file")         Opt[key] = val
        elseif(key=="trains_info_file")     Opt[key] = val
        elseif(key=="rotation_file")        Opt[key] = val
        elseif(key=="imposed_delay_repo_path")      Opt[key] = val
        ####################################################################
        elseif(key=="simulate")             Opt[key] = parse(Bool, val)
        elseif(key=="free_platforms")       Opt[key] = parse(Bool, val)
        ####################################################################
        elseif(key=="print_options")        Opt[key] = parse(Bool, val)
        elseif(key=="print_flow")           Opt[key] = parse(Bool, val)
        elseif(key=="print_train_status")   Opt[key] = parse(Bool, val)
        elseif(key=="print_new_train")      Opt[key] = parse(Bool, val)
        elseif(key=="print_train_wait")     Opt[key] = parse(Bool, val)
        elseif(key=="print_train_end")      Opt[key] = parse(Bool, val)
        elseif(key=="print_train_fossile")  Opt[key] = parse(Bool, val)
        elseif(key=="print_train_list")     Opt[key] = parse(Bool, val)
        elseif(key=="print_elapsed_time")   Opt[key] = parse(Bool, val)
        elseif(key=="print_imposed_delay")  Opt[key] = parse(Bool, val)
        elseif(key=="print_tot_delay")      Opt[key] = parse(Bool, val)
        elseif(key=="print_notifications")  Opt[key] = parse(Bool, val)
        elseif(key=="print_rotations")      Opt[key] = parse(Bool, val)
        ####################################################################
        elseif(key=="save_timetable")       Opt[key] = parse(Bool, val)
        ####################################################################
        else println("WARNING: input parameter $key does not exist")
        end
    end

    if VersionNumber(Opt["Version"]) != ProgramVersion
        println("""
                The par.ini file corresponds to an older version of the program.
                Delete it and rerun the simulation to create a new one.
                Version found: $(Opt["Version"]) --- Current version: $ProgramVersion
                """);
        exit(1);
    end

    parsed_args["inject_delays"] || (Opt["imposed_delay_repo_path"] = "None";)

    if !isempty(parsed_args["timetable_file"])
        Opt["timetable_file"] = parsed_args["timetable_file"];
    end
    if !isempty(parsed_args["block_file"])
        Opt["block_file"] = parsed_args["block_file"];
    end

    if Opt["test"]

        @info("Performing multiple speed tests of the simulation core with no output.\n")

        for k in keys(Opt)
            if startswith(k, r"print|save")
                Opt[k] = false
            end
        end

        Opt["imposed_delay_repo_path"] = "None"
    end

    if Opt["print_options"]
        println("########################")
        println("List of input parameters")
        println("########################")
        for i in sort(collect(keys(Opt)))
            println("$i = $(Opt[i])")
        end
        println("########################")
    end

    Opt["print_flow"] && @info("Options loaded, starting the program.")

end




function createIniFile(file::String)

    INI = open(file, "w")
        print(INI,
"""
#key                    value
#############################
Version                 $ProgramVersion # Program's version
#############################
timetable_file          ../data/simulation_data/timetable.csv # contains the timetable to simulate
block_file              ../data/simulation_data/blocks.csv    # contains the nr of tracks for each block
station_file            ../data/simulation_data/stations.csv  # contains info on the operational points with platforms and multiple tracks
rotation_file           None   # list of train dependencies: one train does not start if the other has not arrived
imposed_delay_repo_path None   # contains files with delay assignments, e.g., ../data/delays/
#############################
simulate                1   # if false do not run the simulation but load the data and exit RN,FL
free_platforms          0   # if true, platforms at stations may be used in any direction
#############################
print_options           0   # print out these options
print_flow              0   # notify when a new function starts and ends
print_train_status      0   # notify the status of trains on operation points
print_new_train         0   # notify when a new train is found in the timetable
print_train_wait        0   # notify when a train has to wait because next block is occupied
print_train_end         0   # display train status at their final destination
print_train_fossile     0   # display trains that appear in one station only
print_train_list        0   # display the id of processed trains
print_elapsed_time      0   # display elapsed simulated seconds
print_imposed_delay     0   # display trains with imposed delay
print_tot_delay         1   # print the total delay at the end of simulation
print_notifications     0   # the simulation sequential number in stderr
print_rotations         0   # display the trains waiting because the necessary train did not arrive yet
#############################
save_timetable          0   # save the simulated timetables
#############################

"""
)
    close(INI)
    println("Parameter file \"$file\" was missing and a default one was created.\nPlease edit it and rerun.")
    exit()

end
