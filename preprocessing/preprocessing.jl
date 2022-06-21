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

    trains_beginning=parsed_args["trains_beginning"]
    create_delay_files=parsed_args["create_delay_files"]
    trains_station_stop=parsed_args["trains_station_stop"]

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

            #if first row , write it
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


    #if you want to create the beginning of the trains for the generated timetable
    if trains_beginning

        timetable_path="../data/simulation_data/"

        get_trains_begin(out_file_name,timetable_path,timetable_path)
    end

    if trains_station_stop

        timetable_path="../data/simulation_data/"

        get_station_stops(out_file_name,timetable_path,timetable_path)
    end

    if create_delay_files
        ###########################################################################################################
        # LOADING THE FILE trainIni.in for the trains to be delayed
        ###########################################################################################################

        Interval = Dict{String,Int}()
        Trains=String[]

        Interval,Trains=loadTrains()
        delays=Interval["step_beginning"]:Interval["step_length"]:Interval["step_end"]
        #
        # ############################################################################################################
        #
        #reloading the starting df for clarity
        path_out="../data/simulation_data/"


        #removing previous defined delay files
        delays_path="../data/delays/"

        if !isdir(delays_path)
          mkdir(delays_path)
        end
        #
        #cleaning old files
        files=read_non_hidden_files(delays_path)
        for file in files
           rm(delays_path*file)
        end


        if trains_beginning
            outfile = "trains_beginning.ini"

            starts= DataFrame(CSV.File(path_out*outfile, comment="#"))

            #creating a dict from it
            start_dict=Dict((starts.trainid[i] => starts[i,2:4] for i=1:nrow(starts)) )
            #
            #defining the train list and delay list

            #writing the new delay files

            ct=1
            train_keys=collect(keys(start_dict))
            # println(train_keys)
            for train in Trains
                for delay in delays

                    if train in train_keys
                        # println(train,delay)
                        pad=lpad(ct,4,"0")
                        outfile = delays_path*"imposed_delay_simulation_$pad.csv"
                        # println(outfile)
                        f = open(outfile, "w")

                        println(f,"trainid,block,delay")
                        println(f,train,",",start_dict[train].block,",",delay)


                        close(f)

                        ct+=1
                    end
                end
            end

        elseif trains_station_stop
            outfile = "trains_stations.ini"

            starts= DataFrame(CSV.File(path_out*outfile, comment="#"))

            #creating a dict from it
            start_dict=Dict((starts.trainid[i] => starts[i,2:4] for i=1:nrow(starts)) )
            #
            #defining the train list and delay list



            #writing the new delay files

            ct=1
            train_keys=collect(keys(start_dict))
            # println(train_keys)
            for i in 1:nrow(starts)-1

                for delay in delays


                        # println(train,delay)

                    train=starts[i,:].trainid
                    block=starts[i,:].block

                    pad=lpad(ct,4,"0")
                    outfile = delays_path*"imposed_delay_simulation_$pad.csv"
                    # println(outfile)
                    f = open(outfile, "w")

                    println(f,"trainid,block,delay")
                    println(f,train,",",block,",",delay)


                    close(f)

                    ct+=1

                end
            end
        end



        @info "Delay files created."
    end

@info "Ending main()"
end

############################################################################################################
#Parses files of delay injection

function loadTrains(file::String="./trainIni.in")
    if !isfile(file)
        createTrainIni(file)
    end

    Interval = Dict{String,Any}()
    Trains=[]
    for line in eachline(file)
        occursin(r"^#", line) && continue # ignore lines beginning with #
        df = split(line, r"\s+")
        length(df) < 1 && continue # ignore empty lines
        key = df[1]
        ####################################################################
        if(key=="step_beginning") Interval[key]=parse(Int64, df[2])
        ####################################################################
        elseif(key=="step_end") Interval[key]=parse(Int64, df[2])
        elseif(key=="step_length") Interval[key]=parse(Int64, df[2])
        else push!(Trains,key)
        end
    end

    println("File of train delay injection parsed.")

    return Interval,Trains
end

function isStation(bst_name::AbstractString)
     a = split(bst_name, "-");
     return a[1] == a[2]
end

############################################################################################################
#gets the stations in which the train stops
function get_station_stops(timetable_name::AbstractString,timetable_path::AbstractString,path_out::AbstractString)

    outfile = "trains_stations.ini"
    #printing out the file



    df = DataFrame(CSV.File(timetable_path*timetable_name))

    durchfahrt_set=["Durchfahrt","Durchfahrt_out"]

    if !isfile(path_out*outfile)

        f = open(path_out*outfile, "w")
        println(f,"trainid,block,first_time,second_time")
        #getting begins array of beginnings of trains

        train_list=unique(df.trainid)



        for train in train_list



            df2=df[isequal.(df.trainid,train),:]

             if nrow(df2) >= 2

                for i in 1:nrow(df2)-1

                    bts=df2[i,:].opid
                    type=df2[i,:].kind

                    blk=df2[i,:].opid*"-"*df2[i+1,:].opid

                    if isStation(blk) && type ∉ durchfahrt_set
                        println(f,train,",",blk,",",df2[i,:].duetime,",",df2[i+1,:].duetime)
                    end

                end

            else
                println("df $df2 has less than 2 rows")
            end

        end


        close(f)
        println("trains_beginning.ini created.")

    else println("Trains stations file already present, using it.")
    end
end


############################################################################################################
#function that reads the timetable and returns the events of beginning of trains if ["Abfahrt","Beginn"] are there
function get_trains_begin(timetable_name::AbstractString,timetable_path::AbstractString,path_out::AbstractString)

    outfile = "trains_beginning.ini"
    #printing out the file
    outfile_unique_trains="unique_trains_running.txt"


    df = DataFrame(CSV.File(timetable_path*timetable_name))



    if !isfile(path_out*outfile)

        f = open(path_out*outfile, "w")
        println(f,"trainid,block,first_time,second_time")
        #getting begins array of beginnings of trains

        train_list=unique(df.trainid)

        f_unique=open(outfile_unique_trains, "w")

        for train in train_list

            println(f_unique,train)

            df2=df[isequal.(df.trainid,train),:]

             if nrow(df2) >= 2


                # if !issubset(["Begin"], df2.kind) && !issubset(["Abfahrt"], df2.kind)
                #     println(f,df2[1,:].trainid,",",df2[1,:].opid*"-"*df2[2,:].opid,",",df2[1,:].duetime,",",df2[2,:].duetime)
                #     continue
                # end
                #
                # first_idx=findfirst(in(["Abfahrt","Beginn"]), df2.kind)
                first_idx=1

                nrows=nrow(df2[first_idx:end,:])
                # println(nrows,df2[first_idx,:].trainid,",",df2[first_idx,:].opid*"-"*df2[first_idx+1,:].opid,",",df2[first_idx,:].duetime,",",df2[first_idx+1,:].duetime)

                if nrows <2
                    # println(df2[first_idx,:].trainid,",",df2[first_idx-1,:].opid*"-"*df2[first_idx,:].opid,",",df2[first_idx-1,:].duetime,",",df2[first_idx,:].duetime)
                    println(f,df2[first_idx,:].trainid,",",df2[first_idx-1,:].opid*"-"*df2[first_idx,:].opid,",",df2[first_idx-1,:].duetime,",",df2[first_idx,:].duetime)
                else
                    # println(df2[first_idx,:].trainid,",",df2[first_idx,:].opid*"-"*df2[first_idx+1,:].opid,",",df2[first_idx,:].duetime,",",df2[first_idx+1,:].duetime)
                    println(f,df2[first_idx,:].trainid,",",df2[first_idx,:].opid*"-"*df2[first_idx+1,:].opid,",",df2[first_idx,:].duetime,",",df2[first_idx+1,:].duetime)
                end

            else
                println("df $df2 has less than 2 rows")
            end

        end

        close(f_unique)
        close(f)
        println("trains_beginning.ini created.")

    else println("Trains beginning file already present, using it.")
    end
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
preprocessing()
