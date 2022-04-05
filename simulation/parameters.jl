"""
This file contains the functions to load the simulation options from
/data/simulation_data/par.ini
If not existing, creates one as default
"""
function loadOptions(parsed_args::Dict)


    file=parsed_args["ini"]

    Opt["test"]=parsed_args["test"]
    Opt["catch_conflict_flag"]=parsed_args["catch_conflict_flag"]
    Opt["multi_stations_flag"]=parsed_args["multi_stations_flag"]

    if !isfile(file)
        createIniFile(file)
    end


    for line in eachline(file)
        occursin(r"^#", line) && continue # ignore lines beginning with #
        df = split(line, r"\s+")
        length(df) < 2 && continue # ignore empty lines
        key = df[1] ; val = df[2]
        ####################################################################
        # if(key=="TEST") Opt[key] = parse(Int, val)
        ####################################################################
        if(key=="block_file")       Opt[key] = val
        elseif(key=="timetable_file")   Opt[key] = val
        elseif(key=="opoint_file")      Opt[key] = val
        elseif(key=="imposed_delay_file")      Opt[key] = val
        elseif(key=="imposed_delay_repo_path")      Opt[key] = val
        elseif(key=="trains_info_file")      Opt[key] = val

        ####################################################################
        elseif(key=="simulate") Opt[key] = parse(Bool, val)
        ####################################################################
        elseif(key=="minrnd") Opt[key] = parse(Float64, val)
        elseif(key=="maxrnd") Opt[key] = parse(Float64, val)
        ####################################################################
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
        elseif(key=="print_notifications")      Opt[key] = parse(Bool, val)
        ####################################################################
        else println("WARNING: input parameter $key does not exist")
        end
    end

    parsed_args["inject_delays"] || (Opt["imposed_delay_repo_path"] = "None")

    if parsed_args["test"]>0

        print("\nPerforming speed test with no output.\nPlease be patient. ")

        for k in keys(Opt)
            if occursin(r"^print", k)
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

    Opt["print_flow"] && println("Options loaded, starting the program.")

end




function createIniFile(file::String)

    INI = open(file, "w")
        print(INI,
"""
#key                    value
#############################
# TEST                    0   # if true perform a test: 1 use @time, 2 use @btime
#############################
block_file              ../data/simulation_data/blocks.csv
timetable_file          ../data/simulation_data/timetable.csv
opoint_file             ../data/simulation_data/betriebstellen.csv
trains_info_file        ../data/simulation_data/trains_info-25.03.19.csv
imposed_delay_repo_path ../data/delays/
#############################
simulate                1   # if false do not run the simulation but load the data and exit RN,FL
#############################
minrnd                  1.0 # Simple way to generate variations in the real timetable
maxrnd                  1.0 # block time is multiplicated by uniform minrnd<r<maxrnd
#############################
#############################
print_options           1   # print out these options
print_flow              1   # notify when a new function starts and ends
print_train_status      0   # notify the status of trains on operation points
print_new_train         0   # notify when a new train is found in the timetable
print_train_wait        0   # notify when a train has to wait because next block is occupied
print_train_end         1   # display train status at their final destination
print_train_fossile     0   # display trains that never travel (?)
print_train_list        0   # display the id of processed trains
print_elapsed_time      0   # display elapsed simulated seconds
print_imposed_delay     1   # display trains with imposed delay
print_tot_delay         1   # print the total delay at the end of simulation
print_notifications     1   # the simulation number in stderr
#############################

"""
)
    close(INI)
    println("Parameter file \"$file\" was missing and a default one was created.\nPlease edit it and rerun.")
    exit()

end
