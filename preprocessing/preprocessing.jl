using DataFrames, CSV, Dates
include("parser.jl")

function dateToSeconds(d::String31)::Int
"""
Given a string in the format "yyyy-mm-dd HH:MM:SS"
returns the number of seconds elapsed from the epoch
"""
    dt::DateTime = Dates.DateTime(d, "dd.mm.yyyy HH:MM:SS")
    return Int(floor(datetime2unix(dt)))
    #return (Dates.hour(dt)*60+Dates.minute(dt))*60+Dates.second(dt)
end
function dateToSeconds(d::Int)::Int
"""
If the input is an Int do nothing
assuming that it is already the number of seconds elapsed from the epoch
"""
    return d
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


############################################################################################################
# Creates the initial delay file if not present

function createTrainIni(file::String)

    INI = open(file, "w")
        print(INI,
"""
#key                    value
#############################
#Range for the delay injected
#############################
step_beginning         0
step_end               3000
step_length            300
#############################
#List of trains to be delayed
#############################
SB24686
"""
)
    close(INI)
    println("Initial train file \"$file\" was missing and a default one was created.\nPlease edit it and rerun.")
    exit()

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

############################################################################################################
function read_non_hidden_files(repo)::Vector{String}
    return filter(!startswith(".") ∘ basename, readdir(repo))
end



function inputfile_from_date(date::String,source_path::String,file_base="PAD-Zuglaufdaten_20")::String
    splitting=split(date,".")
    month=parse(Int,splitting[2])
    year=parse(Int,splitting[3])
    trim=div(month,4)+1

    file=source_path*file_base*"$year-0$trim.csv"

    return file
end




function main()

    if VERSION < v"1.6"
        println("Please upgrade Julia to at least version 1.6. Exiting.")
        exit()
    end



    #CLI parser
    parsed_args = parse_commandline()

    date=parsed_args["date"]

    source_path=parsed_args["source_data_path"]

    out_file = open("timetable-$date.csv", "w")

    println(out_file,"trainid,opid,kind,duetime")


    file=inputfile_from_date(date,source_path)

    time_threshold=600 #tempo per valutare se e' un popping
    pause_before_popping=5 #seconds a train stays in the last block mefore killing it and repopping

# special_train_list=["SSB","SR","SNJ","SD","SREX","SRJ","BUS"]
    accepted_traj_code=["Z","E"]


    #load the df
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
    filter!(row -> row.CODE ∈ accepted_traj_code, df)

    #get the df_date
    filter!(row -> (row.date == date ), df)


    separator=","



    for train in unique(df.train_id)



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

        train_id=train
        npops=0


        for i in 1:nrows-1

            bts=df_train[i, :].bts_code
            next_bts=df_train[i+1, :].bts_code
            block=bts*"-"*next_bts
    #             println(train_id,block)
            bts_time=df_train[i, :].scheduled_time
            next_bts_time=df_train[i+1, :].scheduled_time

            bts_kind=df_train[i, :].kind
            next_bts_kind=df_train[i+1, :].kind


            #if first raw , write it
            if i==1
                if bts != next_bts
                    args=(train_id,bts,"Beginn",dateToSeconds(bts_time)-pause_before_popping)
                    println(out_file,join(args, separator))
                end

                args=(train_id,bts,bts_kind,dateToSeconds(bts_time))
                println(out_file,join(args, separator))


            end

            block_time=dateToSeconds(next_bts_time)-dateToSeconds(bts_time)

            #if time is big
            if (block_time > time_threshold)

                #not existing block
                if (bts!=next_bts)


                    #updating pops
                    npops+=1
                    train_id=train*"_pop$npops"

                    #popping train
                    args=(train_id,next_bts,"Abfahrt",dateToSeconds(next_bts_time))
                    println(out_file,join(args, separator))


#                     args=(train_id,next_bts,"Abfahrt",dateToSeconds(next_bts_time)+pause_before_popping)
#                     println(out_file,join(args, separator))

                #big time, but block exists,still save it
                else

#                     println("time exceeding,but in real block, writing it")

                    args=(train_id,next_bts,next_bts_kind,dateToSeconds(next_bts_time))
                    println(out_file,join(args, separator))
                end

            else
                #save it
#                 println("time exceeding,but in real block, writing it")
                args=(train_id,next_bts,next_bts_kind,dateToSeconds(next_bts_time))
                println(out_file,join(args, separator))
            end

        end

    end
    close(out_file)
end

#if train_popnr has less than 2 row, what to do
# nrows=nrow(df3)
#             if nrows < 2
#                 println("$train has too few rows,adding one in $(df3[1, :].opid)")
#                 args=(train_id,df3[1, :].opid,df3[1, :].kind,dateToSeconds(df3[1, :].duetime))
#                 println(out_file,join(args, separator))
#
#                 args=(train_id,df3[1, :].opid,"Ende",dateToSeconds(df3[1, :].duetime)+pause_before_popping)
#                 println(out_file,join(args, separator))
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

#     Interval = Dict{String,Any}()
#     Trains=[]
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
