function dateToSeconds(d::AbstractString)::Int
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
function dateToSeconds(d::Missing)::Missing
"""
If the input is missing do nothing
"""
    return missing
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

    Interval = Dict{String,Int}()
    Trains=String[]
    for line in eachline(file)
        occursin(r"^#", line) && continue # ignore lines beginning with #
        df = split(line, r"\s+")
        length(df) < 1 && continue # ignore empty lines
        key = df[1]
        ####################################################################
        if(key=="step_beginning")  Interval[key]=parse(Int64, df[2])
        elseif(key=="step_end")    Interval[key]=parse(Int64, df[2])
        elseif(key=="step_length") Interval[key]=parse(Int64, df[2])
        ####################################################################
        else push!(Trains,key)
        end
    end

    println("File of train delay injection parsed.")

    return Interval,Trains
end

############################################################################################################
function read_non_hidden_files(repo::AbstractString)::Vector{String}
    filelist = basename.(readdir(repo));
    # ignore files starting with . and _
    return filter(x->!occursin(r"^\.|^_",x), filelist)
end



function inputfile_from_date(date::String,source_path::String,file_base="PAD-Zuglaufdaten_20")::String
    splitting=split(date,".")
    month=parse(Int,splitting[2])
    year=parse(Int,splitting[3])
    trim=div(month-1,3)+1

    file=source_path*file_base*"$year-0$trim.csv"

    return file
end

"""
Modify the schedule of a train by adding a buffer in selected stations
"""
function buffering(dft::AbstractDataFrame, buffer::Int)

# @info "checkpoint 1"

    list_of_trains = ["R_2206", "R_2208", "R_2210", "R_2212", "R_22282",
        "R_22302", "R_22322", "R_22342", "R_2308", "R_2310", "R_2312",
        "R_2314", "R_7404", "SB_22354", "SB_23316", "SB_29296", "SB_29336"];

    list_of_stations = ["LB", "MD", "MI"];
    # list_of_stations = ["FLD", "LB", "BVS", "BF H1", "MD", "LG", "MI", "WSP"];

    train = dft[1,:train_id];

    train in list_of_trains || return;
    # @info "checkpoint 2"

    sort!(dft, :scheduled_time); # it was sorted already but let's be sure
    # scheduled_time was aready converted into Int
    increment = 0;
    for i = 1:nrow(dft)
        dft.scheduled_time[i] += increment;
        if (dft.bts_code[i] in list_of_stations) && (dft.kind[i] == "Abfahrt")
            dft.scheduled_time[i] += buffer;
            increment += buffer;
        end
    end
end
