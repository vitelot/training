function loadOptions(file::String="run/par.ini")
    if !isfile(file)
        createIniFile(file)
    end

    for line in eachline(file)
        occursin(r"^#", line) && continue # ignore lines beginning with #
        df = split(line, r"\s+")
        length(df) < 2 && continue # ignore empty lines
        key = df[1] ; val = df[2]
        ####################################################################
        if(key=="TEST") Opt[key] = parse(Int, val)
        ####################################################################
        elseif(key=="block_file")       Opt[key] = val
        elseif(key=="timetable_file")   Opt[key] = val
        elseif(key=="opoint_file")      Opt[key] = val
        elseif(key=="imposed_delay_file")      Opt[key] = val
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
        ####################################################################
        else println("WARNING: input parameter $key does not exist")
        end
    end
    if Opt["TEST"]>0
        print("\nPerforming speed test with no output.\nPlease be patient. ")
        for k in keys(Opt)
            if occursin(r"^print", k)
                Opt[k] = false
            end
        end
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
end

function createIniFile(file::String)

    INI = open(file, "w")
        print(INI,
"""
#key                    value
#############################
TEST                    0   # if true perform a test: 1 use @time, 2 use @btime
#############################
block_file              data/blocks.csv
timetable_file          data/timetable.csv
opoint_file             data/betriebstellen.csv
imposed_delay_file      data/imposed_delay.csv
#############################
simulate                1   # if false do not run the simulation but load the data and exit RN,FL
#############################
minrnd                  1.0 # Simple way to generate variations in the real timetable
maxrnd                  1.0 # block time is multiplicated by uniform minrnd<r<maxrnd
#############################
#############################
print_options           1   # print out these options
print_flow              1   # notify when a new function starts and ends
print_train_status      1   # notify the status of trains on operation points
print_new_train         1   # notify when a new train is found in the timetable
print_train_wait        1   # notify when a train has to wait because next block is occupied
print_train_end         1   # display train status at their final destination
print_train_fossile     1   # display trains that never travel (?)
print_train_list        1   # display the id of processed trains
print_elapsed_time      1   # display elapsed simulated seconds
print_imposed_delay     1   # display trains with imposed delay
#############################
"""
)
    close(INI)
    println("Parameter file \"$file\" was missing and a default one was created.\nPlease edit it and rerun.")
    exit()

end