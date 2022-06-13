@info "Loading libraries"
using DataFrames, CSV, Dates
include("parser.jl")
include("exo_delays.jl")
include("functions.jl")
include("rotations.jl")
@info "Compiling."

function preprocessing()
@info "Starting preprocessing"

    if VERSION < v"1.6"
        println("Please upgrade Julia to at least version 1.6. Exiting.")
        exit()
    end

    TIME_THRESHOLD            = 600; #seconds. tempo per valutare se e' un popping
    PAUSE_BEFORE_POPPING      = 5;   #seconds a train stays in the last block mefore killing it and repopping
    ACCEPTED_TRAJ_CODE        = ["Z","E"];
    FAST_STATION_TRANSIT_TIME = 10;  # time in sec that a train is supposed to need to go through a station while transiting
    SEPARATOR                 = ","; # separates fields in the output csv file
    POPPING_IN_WAIT_IN_STATION= 60;  # stays this time in seconds in popping station

    #CLI parser
    parsed_args = parse_commandline()

    date          = parsed_args["date"]
    in_file       = parsed_args["file"]
    source_path   = parsed_args["source_data_path"]
    nr_exo_delays = parsed_args["exo_delays"];
    use_real_time = parsed_args["use_real_time"];
    split_transit = parsed_args["split_transits"];
    find_rotations= parsed_args["rotations"];
    buffering_sec = parsed_args["buffering"];

    if (!isdir(source_path))
        println("No data folder $source_path is available.");
        println("Doing nothing and exiting. Good luck.");
        exit();
    end

    if in_file == ""
        out_file_name = "timetable-$date.csv"
        file=inputfile_from_date(date,source_path)
    else
        out_file_name = "timetable_$in_file"
        file = source_path * in_file; #inputfile_from_date(date,source_path)
    end

    out_file = open(out_file_name, "w")

    println(out_file,"trainid,opid,kind,duetime")

# special_train_list=["SSB","SR","SNJ","SD","SREX","SRJ","BUS"]

    #load the df
@info "Loading data"
    df=CSV.read(file,DataFrame)

    select!(df,
           :Betriebstag            => :date,
           [:Zuggattung, :Zugnr]   => ByRow((x,y) -> string(x, "_",  y)) => :train_id,
           "BST Code Anlieferung"  => :bts_code,
           "Zuglaufmodus Code"     => :CODE,
           "Sollzeit R"            => :scheduled_time,
           :Istzeit                => :real_time,
           "Messpunkt Bez"         => :kind,
           Between(:Tfz1, :Tfz5)
           )

    #get the df_date
    if in_file == ""
        filter!(row -> (row.date == date ), df)
    end

    #take only real running trains
    filter!(row -> row.CODE ∈ ACCEPTED_TRAJ_CODE, df)

    find_rotations && Rotations(copy(df));

    if use_real_time
        df.scheduled_time = df.real_time;
        println("*** Using the real timetable instead of the planned one ***")
    end

    # convert date format in seconds alltogether
    dropmissing!(df, :scheduled_time)
    df.scheduled_time = dateToSeconds.(df.scheduled_time);

    nroftrains = length(unique(df.train_id));
    println("Found $nroftrains trains")

@info "Cycling through trains"

    gd = groupby(df, :train_id);
    df = nothing;

    for i = 1:length(gd)
    # for train in unique(df.train_id)
        df_train = gd[i];
        train = df_train.train_id[1];

        sort!(df_train, :scheduled_time);

        nrows=nrow(df_train)
        if nrows == 1 # remove fossiles already here
            nroftrains -= 1
            continue
        end

        missing_in_columns=[count(ismissing,col) for col in eachcol(df_train)]

        #if trajectory has too many missing in scheduled, kill
        if (missing_in_columns[5] > nrows/2)
            println("train $train has too many nans $missing_in_columns,nrows $nrows skippig it; ")
            continue
        end

        if buffering_sec > 0
            buffering(df_train, buffering_sec);
        end

        nrows=nrow(df_train)

        train_id=train
        npops=0


        for i in 1:nrows-1 # removes trains with one event

            bts      = df_train[i, :bts_code]
            next_bts = df_train[i+1, :bts_code]

            block  = bts*"-"*next_bts

            bts_time      = df_train[i, :scheduled_time]
            next_bts_time = df_train[i+1, :scheduled_time]

            bts_kind      = df_train[i, :kind]
            next_bts_kind = df_train[i+1, :kind]

            # if train transits in station only
            if split_transit && bts_kind == "Durchfahrt"

                if i >1 && df_train[i-1, :bts_code]==bts
                    nothing;
                else
                    time_diff = next_bts_time-bts_time;
                    if time_diff <=1
                        @warn "Train $train_id exceeds speed of light in $bts"
                    end

                    if time_diff <= FAST_STATION_TRANSIT_TIME
                        # next bst is too close
                        args = (train_id, bts, "Durchfahrt_out", bts_time+div(time_diff,2)) #lo faccio domani
                    else
                        # assume a short transit time
                        args = (train_id, bts, "Durchfahrt_out", bts_time+FAST_STATION_TRANSIT_TIME)
                    end

                    println(out_file,join(args, SEPARATOR))
                    # printstyled("Warning: next bst is closer in time less than $FAST_STATION_TRANSIT_TIME seconds: $(next_bts_time-bts_time) sec.\n", bold=true);
                    # printstyled("$args\n", bold=true);
                end

            end

            #if first raw , write it
            if i==1
                if bts != next_bts
                    args=(train_id,bts, "Beginn", bts_time-PAUSE_BEFORE_POPPING)
                    println(out_file,join(args, SEPARATOR))
                end

                args=(train_id, bts, bts_kind, bts_time)
                println(out_file,join(args, SEPARATOR))


            end

            block_time = next_bts_time-bts_time

            #if time is big
            if (block_time > TIME_THRESHOLD)


                if (bts!=next_bts)


                    #updating pops
                    npops+=1
                    train_id=train*"_pop$npops"

                    #popping train
                    if split_transit
                        args=(train_id,next_bts, "Ankunft", next_bts_time-POPPING_IN_WAIT_IN_STATION)
                        println(out_file,join(args, SEPARATOR))
                    end
                    #popping train
                    args=(train_id,next_bts, "Abfahrt", next_bts_time)
                    println(out_file,join(args, SEPARATOR))


#                     args=(train_id,next_bts,"Abfahrt",dateToSeconds(next_bts_time)+PAUSE_BEFORE_POPPING)
#                     println(out_file,join(args, SEPARATOR))

                #big time, but block exists,still save it
                else

#                     println("time exceeding,but in real block, writing it")

                    args=(train_id,next_bts,next_bts_kind, next_bts_time)
                    println(out_file,join(args, SEPARATOR))
                end

            else
                #save it
#                 println("time exceeding,but in real block, writing it")
                args=(train_id,next_bts,next_bts_kind, next_bts_time)
                println(out_file,join(args, SEPARATOR))
            end

        end

    end
    println("Number of trains after cleaning: $nroftrains");
    println();

    close(out_file)
    println("Saving timetable file \"$out_file_name\"")

    ############################################################################################################
    ##MOVING THE UNZIPPED FILES FROM DATA.ZIP TO THE CORRECT DIRS
    ##############################################################################
    path_ini=source_path; # "../data/hidden_data/"

    path_end="../data/simulation_data/"

    isdir(path_end) || mkdir(path_end)

    # move the created file in the working dir
    cp("./$out_file_name", "$(path_end)$out_file_name", force=true)
    mv("./$out_file_name", "$(path_end)timetable.csv", force=true)
    println("Copying \"$out_file_name\" into \"$(path_end)timetable.csv\"")

    file = "blocks.csv";
    if isfile(path_ini*file)
        println("Copying \"$(path_ini*file)\" into \"$(path_end)block.csv\"")
        cp(path_ini*file, path_end*file, force=true)
    else
        println("There is no block data available in the $path_ini folder")
      # for file in filter(x -> endswith(x, ".csv"), readdir(path_ini))
      #     mv(path_ini*file,path_end*file,force=true)
      # end
    end

    if nr_exo_delays>0
        SampleExoDelays(
            "../data/hidden_data/NumberOfDelays.csv",
            "../data/simulation_data/timetable.csv",
            "../data/hidden_data/DelayList.csv",
            "../data/delays/imposed_exo_delay.csv",
            nr_exo_delays)
    end
@info "Ending preprocessing"
end


############################################################################################################
preprocessing()
