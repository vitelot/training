using DataFrames, CSV

############################################################################################################
#function that reads the timetable and returns the events of beginning of trains if ["Abfahrt","Beginn"] are there
function get_train_begin(timetable_path::AbstractString,train_id::AbstractString)::Array{Any}
    df = DataFrame(CSV.File(timetable_path*"timetable.csv"))

    df=df[isequal.(df.trainid,train_id),:]

    if !issubset(["Begin"], df.kind) && !issubset(["Abfahrt"], df.kind)
        return [0,0,0,0]
    end

    df=df[findfirst(in(["Abfahrt","Beginn"]), df.kind), :]

    arr=[df.trainid,df.opid,df.kind,df.duetime]


    df= nothing
    return arr
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
step_length            60
#############################
#List of trains to be delayed
#############################
SB22674
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








function main()

    if VERSION < v"1.6"
        println("Please upgrade Julia to at least version 1.6. Exiting.")
        exit()
    end

    ############################################################################################################
    path_ini="../data/data/"

    path_end="../data/simulation_data/"

    if !isdir(path_end)
      mkdir(path_end)
    end

    if !isdir(path_ini)
      path_alternative="../data/"
      for file in filter(x -> endswith(x, ".csv"), readdir(path_alternative))
          mv(path_alternative*file,path_end*file,force=true)
      end
    else
      for file in filter(x -> endswith(x, ".csv"), readdir(path_ini))
          mv(path_ini*file,path_end*file,force=true)
      end
    end
    ############################################################################################################

    #getting the timetable df
    timetable_path="../data/simulation_data/"
    df = DataFrame(CSV.File(timetable_path*"timetable.csv"))

    path_out="../data/simulation_data/"
    outfile = "trains_beginning.ini"


    #if file not present, create trains_beginning.ini
    if !isfile(path_out*outfile)
        #getting begins array of beginnings of trains
        begins=[]
        train_list=unique(df.trainid)
        for train in train_list
            push!(begins, get_train_begin(timetable_path,train))
        end


        #filter begins from zeros
        b=[0,0,0,0]
        filter!(x->x≠b,begins)

        #printing out the file

        f = open(path_out*outfile, "w")
        println(f,"trainid,opid,kind,duetime")
        for i in 1:length(begins)

            println(f,begins[i][1],",",begins[i][2],",",begins[i][3],",",begins[i][4])

        end
        close(f)
        println("trains_beginning.ini created.")

    else println("Trains beginning file already present, using it.")
    end


    println("Got train beginnings.")

    ############################################################################################################

    Interval = Dict{String,Any}()
    Trains=[]

    Interval,Trains=loadTrains()

    ############################################################################################################

    #reloading the starting df for clarity
    path_out="../data/simulation_data/"
    outfile = "trains_beginning.ini"
    starts= DataFrame(CSV.File(path_out*outfile, comment="#"))

    #creating a dict from it
    start_dict=Dict((starts.trainid[i] => starts[i,2:4] for i=1:nrow(starts)) )

    #defining the train list and delay list
    #bad_trains=String["SB22674","SB24686"]#String["SB22674","SB24686","R2246","R2265","R2248","RJ750","SB21714"]

    delays=Interval["step_beginning"]:Interval["step_length"]:Interval["step_end"]


    #removing previous defined delay files
    delays_path="../data/delays/"

    if !isdir(delays_path)
      mkdir(delays_path)
    end

    files=read_non_hidden_files(delays_path)
    for file in files
       rm(delays_path*file)
    end

    #writing the new delay files

    count=1
    train_keys=collect(keys(start_dict))
    for train in Trains
        for delay in delays
            if train in train_keys
                outfile = delays_path*"imposed_delay_simulation_$count.csv"
                f = open(outfile, "w")

                println(f,"trainid,opid,kind,duetime,delay")
                println(f,train,",",start_dict[train].opid,",",start_dict[train].kind,",",start_dict[train].duetime,",",delay)

                close(f)

                count+=1
            end
        end
    end

    println("Delay files created.")

end

############################################################################################################
main()
