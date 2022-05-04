@info "Loading libraries"
using DataFrames, CSV, Dates
include("parser.jl")
include("exo_delays.jl")
include("functions.jl")
@info "Compiling."

function main()
@info "Starting main()"

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
    df=CSV.read(file,DataFrame, delim=',', decimal=',')

    rename!(df,:"BST Code Anlieferung" => :bts_code)
    rename!(df,:Betriebstag => :date)

    rename!(df,:Istzeit => :real_time)
    rename!(df,:"Messpunkt Bez" => :kind)
    rename!(df,:"Sollzeit R" => :scheduled_time)
    rename!(df,:"Zuglaufmodus Code" => :CODE)
    df.train_id = string.(df.Zuggattung, "_",  df.Zugnr)


    select!(df, ([:date,:train_id,:bts_code,:CODE,:scheduled_time,:real_time,:kind]))

    #take only real running trains
    filter!(row -> row.CODE ∈ ACCEPTED_TRAJ_CODE, df)

    #get the df_date
    if in_file == ""
        filter!(row -> (row.date == date ), df)
    end

    if use_real_time
        df.scheduled_time = df.real_time;
        println("*** Using real time instead of scheduled ***")
    end

    # convert date format in seconds alltogether
    df.scheduled_time = dateToSeconds.(df.scheduled_time);


@info "Cycling through trains"
    for train in unique(df.train_id)
        # println("$train");
        df_train=filter(row -> (row.train_id == train), df)
        sort!(df_train, [order(:scheduled_time, rev=false)])

        nrows=nrow(df_train)

        missing_in_columns=[count(ismissing,col) for col in eachcol(df_train)]

        #if trajectory has too many missing in scheduled, kill
        if (missing_in_columns[5] > nrows/2)
            println("train $train has too many nans $missing_in_columns,nrows $nrows skippig it; ")
#             println("theo missing: $(missing_in_columns[4]), nrows $nrows")
            continue
        end


        dropmissing!(df_train, :scheduled_time)

        nrows=nrow(df_train)
        train_id=train
        npops=0


        for i in 1:nrows-1

            bts      = df_train[i, :].bts_code
            next_bts = df_train[i+1, :].bts_code

            block  = bts*"-"*next_bts

            bts_time      = df_train[i, :].scheduled_time
            next_bts_time = df_train[i+1, :].scheduled_time

            bts_kind      = df_train[i, :].kind
            next_bts_kind = df_train[i+1, :].kind

            # if train transits in station only
            if bts_kind == "Durchfahrt"
                time_diff = next_bts_time-bts_time;
                if time_diff <= FAST_STATION_TRANSIT_TIME
                    # next bst is too close
                    args = (train_id, bts, "Durchfahrt_out", bts_time+time_diff-2)
                else
                    # assume a short transit time
                    args = (train_id, bts, "Durchfahrt_out", bts_time+FAST_STATION_TRANSIT_TIME)
                end

                println(out_file,join(args, SEPARATOR))
                # printstyled("Warning: next bst is closer in time less than $FAST_STATION_TRANSIT_TIME seconds: $(next_bts_time-bts_time) sec.\n", bold=true);
                # printstyled("$args\n", bold=true);
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
                    args=(train_id,next_bts, "Ankunft", next_bts_time-POPPING_IN_WAIT_IN_STATION)
                    println(out_file,join(args, SEPARATOR))
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
        println("Copying \"$(path_ini*file)\" into \"$(path_end)timetable.csv\"")
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
@info "Ending main()"
end

#if train_popnr has less than 2 row, what to do
# nrows=nrow(df3)
#             if nrows < 2
#                 println("$train has too few rows,adding one in $(df3[1, :].opid)")
#                 args=(train_id,df3[1, :].opid,df3[1, :].kind,dateToSeconds(df3[1, :].duetime))
#                 println(out_file,join(args, SEPARATOR))
#
#                 args=(train_id,df3[1, :].opid,"Ende",dateToSeconds(df3[1, :].duetime)+PAUSE_BEFORE_POPPING)
#                 println(out_file,join(args, SEPARATOR))
#     #             println(df3)
#                 continue
#             end


    ############################################################################################################
    ##MOVING THE UNZIPPED FILES FROM DATA.ZIP TO THE CORRECT DIRS
    ##############################################################################
    # path_ini="../data/data/"
    #
    # path_end="../data/simulation_data/"
    #
    # if !isdir(path_end)
    #   mkdir(path_end)
    # end
    #
    # if !isdir(path_ini)
    #   path_alternative="../data/"
    #   for file in filter(x -> endswith(x, ".csv"), readdir(path_alternative))
    #       mv(path_alternative*file,path_end*file,force=true)
    #   end
    # else
    #   for file in filter(x -> endswith(x, ".csv"), readdir(path_ini))
    #       mv(path_ini*file,path_end*file,force=true)
    #   end
    # end



    ############################################################################################################
    ## CREATE THE FILE FOR THE BEGINNING BLOCK FOR THAT TIMETABLE
    ############################################################################################################
    # #getting the timetable df
    # timetable_path="../data/simulation_data/"
    # #df = DataFrame(CSV.File(timetable_path*"timetable.csv"))
    #
    # path_out="../data/simulation_data/"
    # outfile = "trains_beginning.ini"
    # timetable_name="timetable-25.03.19-filtered.csv"
    # get_trains_begin(timetable_name,timetable_path,path_out)



    ############################################################################################################
    ## LOADING THE FILE trainIni.in for the trains to be delayed
    ############################################################################################################

#     Interval = Dict{String,Int}()
#     Trains=String[]
#
#     Interval,Trains=loadTrains()
#
#     ############################################################################################################
#
#     #reloading the starting df for clarity
#     path_out="../data/simulation_data/"
#     outfile = "trains_beginning.ini"
#     starts= DataFrame(CSV.File(path_out*outfile, comment="#"))
#
#     #creating a dict from it
#     start_dict=Dict((starts.trainid[i] => starts[i,2:4] for i=1:nrow(starts)) )
#
#     #defining the train list and delay list
#
#     delays=Interval["step_beginning"]:Interval["step_length"]:Interval["step_end"]
#
#     # println(delays,Trains)
#
#     #removing previous defined delay files
#     delays_path="../data/delays/"
#
#     if !isdir(delays_path)
#       mkdir(delays_path)
#     end
#
#     files=read_non_hidden_files(delays_path)
#     for file in files
#        rm(delays_path*file)
#     end
#
#     #writing the new delay files
#
#     count=1
#     train_keys=collect(keys(start_dict))
#     # println(train_keys)
#     for train in Trains
#         for delay in delays
#
#             if train in train_keys
#                 # println(train,delay)
#                 outfile = delays_path*"imposed_delay_simulation_$count.csv"
#                 # println(outfile)
#                 f = open(outfile, "w")
#
#                 println(f,"trainid,block,delay")
#                 println(f,train,",",start_dict[train].block,",",delay)
#
#
#                 close(f)
#
#                 count+=1
#             end
#         end
#     end
#
#     println("Delay files created.")
#



############################################################################################################
main()
