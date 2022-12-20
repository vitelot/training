using CSV, DataFrames, LightXML, Dates;

UString = Union{String,Missing};

function getInfra(xroot::XMLElement)::DataFrame
    ##### INFRASTRUCTURE SCHEMA #####
    # <infrastructure id="IS_01" name="infrastructure" timetableRef="TT_01" rollingstockRef="RS_01">
    #   <operationControlPoints>
    #     <ocp id="ocp_MV_2021-12-11_230000" code="3149" name="MV" description="Mitterdorf-Veitsch" parentOcpRef="ocp_MV_2021-12-11_230000">
    #       <propOperational operationalType="station"/>
    #       <geoCoord coord="47.536702 15.513335"/>
    #       <designator register="DB640" entry="Mv" startDate="2021-12-11" endDate="2022-12-10"/>
    #       <designator register="PLC" entry="3149" startDate="2021-12-11" endDate="2022-12-10"/>
    #     </ocp>
    #   </operationControlPoints>
    # </infrastructure>

    @info "Extracting information on operational points";

    Infra = xroot["infrastructure"];
    Ops = Infra[1]["operationControlPoints"][1]["ocp"];

    df = DataFrame(id=UString[], name=UString[], description=UString[], coordinates=UString[]);

    for o in Ops
        id = attribute(o, "id");
        name = attribute(o, "name");
        descr = attribute(o, "description");
        # println(id);
        coord = length(o["geoCoord"]) == 0 ? missing : attribute(o["geoCoord"][1], "coord"); 
        
        push!(df, (id,name,descr,coord));
    end

    @info "\tFound $(length(unique(df.name))) operational points";

    return df;
end

function getVehicles(xroot::XMLElement)::DataFrame

    @info "Extracting information on the rolling stock";

    vehicles = xroot["rollingstock"][1]["vehicles"][1]["vehicle"];
    
    df = DataFrame(id=UString[], code=UString[], description=UString[], name=UString[], category=UString[]);
    for v in vehicles
        # id::UString=missing;
        code::UString=missing;
        descr::UString=missing;
        name::UString=missing;
        cat::UString=missing;

        
        D = attributes_dict(v);
        code  = get(D, "code", missing);
        descr = get(D, "description", missing);
        name  = get(D, "name", missing);
        cat   = get(D, "vehicleCategory", missing);

        # println(D["id"]);
        push!(df, (D["id"], code, descr, name, cat));

    end
    @info "\tFound $(length(unique(df.code))) vehicles";

    return df;
end

function getLocos(xroot::XMLElement, dfvehicles::DataFrame)::DataFrame

    @info "Extracting information on traction vehicles";

    Locos = Dict{String,String}();
    for r in eachrow(dfvehicles)
        ismissing(r.name) && continue;
        Locos[r.id] = r.name;
    end

    formations = xroot["rollingstock"][1]["formations"][1]["formation"];
    D = Dict{String,Vector{String}}();
    for f in formations
        id = attribute(f,"id");
        elements = f["trainOrder"][1]["vehicleRef"];
        get!(D, id, String[]);
        for e in elements
            ref = attribute(e, "vehicleRef");
            push!(D[id], ref);
        end    
    end
    
    # maxnrlocos = maximum(length.(collect(values(D)))); # it was 14

    df = DataFrame(formation=String[], locoref=UString[], loco=UString[]);
    # pp = [string("loco",i)=>UString[] for i = 1:maxnrlocos];
    # insertcols!(df, pp...); 

    for (formation, locorefs) in D
        for locoref in locorefs
            haskey(Locos, locoref) && push!(df, (formation,locoref, Locos[locoref]));
        end
    end
    # remove locos with no serial number
    # filter!(x->occursin(".", x.loco), df);
    replace!(x->occursin(".",x) ? x : missing, df.loco);

    @info "\tFound $(length(unique(df.loco))) traction vehicles";

    return df;
end

function getCategories(xroot::XMLElement)::DataFrame

    @info "Extracting train categories (REX, EC, SB, etc.)"

    timetable = xroot["timetable"][1];

    categories = timetable["categories"][1]["category"];

    dfcat = DataFrame(id=String[], code=String[], name=String[], usage=String[]);
    for cat in categories
        D = attributes_dict(cat);
        push!(dfcat, (D["id"], D["code"], D["name"], D["trainUsage"]));
    end

    return dfcat;
end

function getTrains(xroot::XMLElement)::DataFrame

    @info "Extracting train parts and id number";

    timetable = xroot["timetable"][1];
    trains = timetable["trains"][1]["train"];
    
    maxparts = 0;
    for t in trains
        maxparts = max(maxparts, length(t["trainPartSequence"]));
    end
    # println(maxparts);

    dftrain = DataFrame(id=String[], number=String[], type=String[]);
    # add the necessary clumns to hold the references to train's parts
    pp = [string("partref",i)=>UString[] for i = 1:maxparts];
    insertcols!(dftrain, pp...); 

    parts = Vector{UString}(undef,maxparts);
    for t in trains
        parts .= missing;
        D = attributes_dict(t);
        id = D["id"]; type = D["type"]; n = D["trainNumber"];
        tps = t["trainPartSequence"];
        for i = 1:length(tps);
            parts[i] = attribute(tps[i]["trainPartRef"][1],"ref");
        end
        push!(dftrain, (id, n, type, parts...));
    end

    @info "\tFound $(length(unique(dftrain.number))) train services";

    return dftrain;
end

function getSchedule(xroot::XMLElement)::DataFrame
    @info "Extracting a raw timetable"

    timetable = xroot["timetable"][1];

    trainparts = timetable["trainParts"][1]["trainPart"];

    dfpart = DataFrame();
    pp = [s=>UString[] for s in ["id","catref","formref","oref","type","scheduledtime","realtime"]];
    insertcols!(dfpart, pp...);

    for part in trainparts
        id = attribute(part, "id");
        catref = attribute(part, "categoryRef");
        formref = attribute(part["formationTT"][1], "formationRef");
        if isnothing(formref)
            formref = missing;
        end
        ops = part["ocpsTT"][1]["ocpTT"];
        
        arrival::UString = missing; 
        scheduled_arrival::UString = missing; 
        realtime_arrival::UString = missing; 
        departure::UString = missing; 
        scheduled_departure::UString = missing; 
        realtime_departure::UString = missing; 

        for op in ops
            oref = attribute(op, "ocpRef");
            type = attribute(op, "ocpType");
            remarks = attribute(op, "remarks");
            times = op["times"];

            scheduled_arrival = missing; 
            realtime_arrival = missing; 
            scheduled_departure = missing; 
            realtime_departure = missing; 

            if type == "pass"

                for t in times
                    D = attributes_dict(t);
                    scope = D["scope"];
                    arrival = D["arrival"];
                    arrival_nextday = ifelse(D["arrivalDay"]=="0", false, true);
                    departure_nextday = ifelse(D["departureDay"]=="0", false, true);
                    departure = D["departure"];
                    if arrival != departure
                        @warn "Arrival time is not equal to departure time in type pass ($id, $oref, $scope)";
                    end
                    
                    nd = "";
                    if scope == "actual"
                        arrival_nextday && (nd="+1 ");
                        realtime_arrival = string(nd,arrival);
                    end
                    if scope == "scheduled"
                        arrival_nextday && (nd="+1 ");
                        scheduled_arrival = string(nd,arrival);
                    end
                end
                # println("$id ### $oref");
                push!(dfpart, (id,catref,formref,oref,type,scheduled_arrival,realtime_arrival));
            end
            if type == "stop"
                for t in times
                    D = attributes_dict(t);
                    scope = D["scope"];
                    # println("$id ### $oref");
                    arrival   = get(D, "arrival",   missing);
                    departure = get(D, "departure", missing);
                    arrival_nextday   = ifelse(get(D, "arrivalDay",   "0")=="0", false, true);
                    departure_nextday = ifelse(get(D, "departureDay", "0")=="0", false, true);
                    
                    nda = ndd = "";
                    
                    if scope == "actual"
                        arrival_nextday   && (nda="+1 ");
                        departure_nextday && (ndd="+1 ");
                        realtime_arrival   = ifelse(ismissing(arrival),   missing, string(nda,arrival));
                        realtime_departure = ifelse(ismissing(departure), missing, string(ndd,departure));
                    end

                    if scope == "scheduled"
                        arrival_nextday   && (nda="+1 ");
                        departure_nextday && (ndd="+1 ");
                        scheduled_arrival   = ifelse(ismissing(arrival),   missing, string(nda,arrival));
                        scheduled_departure = ifelse(ismissing(departure), missing, string(ndd,departure));
                    end
                end
                if !ismissing(scheduled_arrival) || !ismissing(realtime_arrival)
                    if isnothing(remarks)  
                        ttype = "arrival";
                    elseif remarks == "Bereitstellung"
                        ttype = "start";
                    elseif remarks == "Abstellung"
                        ttype = "end"
                    end
                    push!(dfpart, (id,catref,formref,oref,ttype,scheduled_arrival,realtime_arrival));
                end
                if !ismissing(scheduled_departure) || !ismissing(realtime_departure)
                    if isnothing(remarks)  
                        ttype = "departure";
                    elseif remarks == "Bereitstellung"
                        ttype = "start";
                    elseif remarks == "Abstellung"
                        ttype = "end"
                    end
                    push!(dfpart, (id,catref,formref,oref,"departure",scheduled_departure,realtime_departure));
                end
            end
        end
    end
    @info "\tFound $(nrow(dfpart)) events";

    return dfpart;
end

function generatePAD(dfs::DataFrame, 
                    dfcat::DataFrame, dfinfra::DataFrame, 
                    dftrain::DataFrame, dflocos::DataFrame; 
                    only_passenger_trains=true)::DataFrame

    @info "Generating the schedule (PAD-Zuglauf format)"

    if only_passenger_trains
        filter!(x->x.usage=="passenger", dfcat);
        passenger_trains_catref = unique(dfcat.id);

        filter!(x->x.catref ∈ passenger_trains_catref, dfs);
    end

    Dops = Dict{String,String}();
    for r in eachrow(dfinfra)
        Dops[r.id] = r.name;
    end
    Dcat =  Dict{String,String}();
    for r in eachrow(dfcat)
        Dcat[r.id] = r.code;
    end
    Dtrain = Dict{String,String}();
    for r in eachrow(dftrain)
        for i = 4:length(r)
            ismissing(r[i]) && continue;
            Dtrain[r[i]] = r.number;
        end
    end
    Dlocos = Dict{UString,Set{String}}();
    Dlocos[missing] = Set{String}();
    for r in eachrow(dflocos)
        get!(Dlocos, r.formation, Set{String}());
        ismissing(r.loco) || push!(Dlocos[r.formation], r.loco);
    end
    maxlocos = maximum(length.(values(Dlocos)));
    locosymbol = [Symbol("loco",i) for i =1:maxlocos];
    function fillLocos(S::Set{String}, n::Int)::Vector{UString}
        v = Vector{UString}(missing, n);
        i = 1;
        for loco in S
            v[i] = loco;
            i += 1;
        end
        return v;
    end

    select(dfs,
            :catref => ByRow(x->Dcat[x])    => :category,
            :id     => ByRow(x->Dtrain[x])  => :number,
            :oref   => ByRow(x->Dops[x])    => :op,
            :type,
            :scheduledtime,
            :realtime,
            :formref => ByRow(x->fillLocos(Dlocos[x],maxlocos)) => locosymbol
            )
end

function railml2csv(infile = "data/railml_2022-08-05.xml")::DataFrame

    day = match(r"\d+-\d+-\d+", infile).match;

    @info "Reading file $infile";
    xdoc = parse_file(infile);

    # get the root element
    xroot = root(xdoc);  # an instance of XMLElement: <railml>

    dfinfra = getInfra(xroot);
    # CSV.write("data/infra.csv", dfinfra);

    dfvehicles = getVehicles(xroot);
    # CSV.write("data/vehicles.csv", dfvehicles);

    dflocos = getLocos(xroot, dfvehicles);
    # CSV.write("data/locos.csv", dflocos);

    dfcat = getCategories(xroot);
    # CSV.write("data/categories.csv", dfcat);

    dftrain = getTrains(xroot);
    # CSV.write("data/trains.csv", dftrain);

    dfschedule = getSchedule(xroot);
    # CSV.write("data/schedule.csv", dfschedule);

    DF = generatePAD(dfschedule, dfcat, dfinfra, dftrain, dflocos);
    outfile = "data/PAD-$(day).csv";

    @info "\t Saving the schedule onto file $outfile";
    CSV.write(outfile, DF);

    return DF;
end

railml2csv("data/railml_2022-08-05.xml");

# free(xdoc);

