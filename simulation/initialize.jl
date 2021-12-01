"""
This file contains all the functions that have to initialize the system.
For example, loading the network, the block characteristics, the timetables
"""

function loadNetwork()::Network
    RN = Network()
    #loadOPoints!(RN)
    loadBlocks!(RN)
    RN
end

function loadOPoints!(file::String, RN::Network)

    file  = Opt["opoint_file"]
    df = DataFrame(CSV.File(file, comment="#"))

    for i = 1:nrow(df)
        name = string(df.id[i])
        op = OPoint(
                name,
                i,
                df.lat[i],
                df.long[i],
                String[],
                String[],
                false
        )
        RN.n += 1
        RN.nodes[name]=op
    end
    df = nothing # explicitly free the memory
end


function loadBlocks!(RN::Network)

    fileblock = Opt["block_file"]
    df = DataFrame(CSV.File(fileblock, comment="#"))

    for i = 1:nrow(df)
        name = df.id[i]
        b = Block(
                name,
                # i,
                df.tracks[i],
                0,
                Set{String}()
        )
        RN.nb += 1
        RN.blocks[name]=b
        # push!(RN.nodes[from].child, to)
        # push!(RN.nodes[to].parent, from)
    end
    df = nothing # explicitly free the memory

    RN.blocks[""] = Block( # the null block
                        "",
                        0,
                        0,
                        Set{String}()
    )
end

function loadInfrastructure()::Network
    RN = loadNetwork()
    Opt["print_flow"] && println("Infrastructure loaded")
    RN
end

function loadFleet()::Fleet

    file = Opt["timetable_file"]

    Opt["print_flow"] && println("Loading fleet information")

    FL = Fleet(0,Dict{String, Train}())
    df = DataFrame(CSV.File(file, comment="#"))
    for i = 1:nrow(df)
        #trainid,opid,kind,duetime = Tuple(df[i,:])
        trainid=string(df.trainid[i])
        duetime = dateToSeconds(df.duetime[i])
        str = Transit(
                trainid,
                df.opid[i],
                df.kind[i],
                duetime
        )
        if !haskey(FL.train, trainid)
            get!(FL.train, trainid,
                    Train(trainid, [str],
                        DynTrain(0,"","",0,0)))
        else
            push!(FL.train[trainid].schedule, str)
        end

    end
    FL.n = length(FL.train)
    df = nothing

    #assignImposedDelay(FL);

    Opt["print_flow"] && println("Fleet loaded ($(FL.n) trains)")
    return FL
end




function read_non_hidden_files(repo)::Vector{String}
    return filter(!startswith(".") ∘ basename, readdir(repo))
end

#customized sorting, for correctly sorting strings based on last digits
function custom_cmp(x::String)
    arr_str = rsplit(x, "_",limit=2)
    str1, _ = arr_str[1], arr_str[2]
    number_idx = findlast(isdigit, arr_str[2])
    num,str2 = SubString(arr_str[2], 1, number_idx), SubString(arr_str[2], number_idx+1, length(arr_str[2]))
    return str1,parse(Int, num)
end





function loadDelays()::Tuple{Vector{Any},Int}
    print_imposed_delay = Opt["print_imposed_delay"];

    n=0
    delays_array=[]
    repo = Opt["imposed_delay_repo_path"]
    files=sort!(read_non_hidden_files(repo), by = custom_cmp)


    if isempty(files)
        print_imposed_delay && println("No imposed delay file was found. Simulating without imposed delays.")
        return nothing;
    end

    for file in files
        delay= DataFrame(CSV.File(repo*file, comment="#"))
        push!(delays_array,delay)
    end

    #print(delays_array)
    n=length(delays_array)
    Opt["print_flow"] && println("Delays loaded. The number of simulations is: ",n)
    delay=nothing

    return (delays_array,n)
end

function resetDelays(FL::Fleet,delays_array::Vector{Any},simulation_id::Int)

    print_imposed_delay = Opt["print_imposed_delay"];

    df = delays_array[simulation_id-1];

    c=0;
    for i = 1:nrow(df)
        (train, op, kind, delay) = df[i,:];

        v = FL.train[train].schedule;
        idx = findfirst(x->x.opid==op && x.kind==kind, v);
        if print_imposed_delay
            if isnothing(idx)
                println("Reset delay: train $train, op $op, kind $kind, not found.");
                continue;
            else
                println("Reset $delay to train $train, $kind at $op.")
            end
        end
        FL.train[train].schedule[idx].imposed_delay.delay = 0;
        c += 1;
    end

    Opt["print_flow"] && println("$c Delays reset");
    df = nothing;

end

function imposeDelays(FL::Fleet,delays_array::Vector{Any},simulation_id::Int)

    print_imposed_delay = Opt["print_imposed_delay"];


    if simulation_id>1
        resetDelays(FL,delays_array,simulation_id);
    end


    df = delays_array[simulation_id];


    c=0;
    for i = 1:nrow(df)
        (train, op, kind, delay) = df[i,:];
        v = FL.train[train].schedule;
        idx = findfirst(x->x.opid==op && x.kind==kind, v);

        if print_imposed_delay
            if isnothing(idx)
                println("Imposing delay: train $train, op $op, kind $kind, not found.");
                continue;
            else
                println("Imposing $delay seconds delay to train $train, $kind at $op.")
            end
        end
        FL.train[train].schedule[idx].imposed_delay.delay = delay;
        c += 1;
    end

    Opt["print_flow"] && println("$c Delays imposed");
    df = nothing;

end

#=function assignImposedDelay(FL::Fleet)
    file = Opt["imposed_delay_file"]
    print_imposed_delay = Opt["print_imposed_delay"];

    if !isfile(file) # do nothing if file does not exist
        print_imposed_delay && println("No imposed delay file was found.")
        return nothing;
    end

    df = DataFrame(CSV.File(file, comment="#"))
    c=0;
    for i = 1:nrow(df)
        (train, op, kind, delay) = df[i,:];
        v = FL.train[train].schedule;
        idx = findfirst(x->x.opid==op && x.kind==kind, v);
        if print_imposed_delay
            if isnothing(idx)
                println("Imposing delay: train $train, op $op, kind $kind, not found.");
                continue;
            else
                println("Imposing $delay seconds delay to train $train, $kind at $op.")
            end
        end
        FL.train[train].schedule[idx].imposed_delay.delay = delay;
        c += 1;
    end

    Opt["print_flow"] && println("$c Delays imposed");
    df = nothing;
end
=#

function initEvent(FL::Fleet)::Dict{Int,Vector{Transit}}

    E = Dict{Int,Vector{Transit}}()

    TB = generateTimetable(FL)

    Opt["print_flow"] && println("Initializing the event table")

    S = Set{String}() # trains circulating

    D = TB.timemap
    t_initial = minimum(keys(D))
    t_final = maximum(keys(D))

    for t = t_initial:t_final
        if haskey(D, t)
            for transit in D[t] # there may be more trains at time t

                trainid = transit.trainid

                if trainid ∉ S # add new train in the current day events
                    get!(E,t,Transit[])
                    push!(E[t], transit)
                    push!(S, trainid)
                    #println("New train $trainid starting at $opid")
                end
            end
        end
    end
    TB = nothing;
    E
end
