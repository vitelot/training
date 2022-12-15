using CSV, DataFrames, LightXML;

cd("preprocessing");
infile = "data/railml_2022-08-05.xml";

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
    return df;
end

function getVehicles(xroot::XMLElement)::DataFrame
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
    return df;
end

function getLocos(xroot::XMLElement, dfvehicles::DataFrame)::DataFrame
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

    df = DataFrame(formation=String[], locoref=UString[], loco=String[]);
    for (formation, locorefs) in D
        for locoref in locorefs
            haskey(Locos, locoref) && push!(df, (formation,locoref, Locos[locoref]));
        end
    end
    return df;
end

xdoc = parse_file(infile);

# get the root element
xroot = root(xdoc);  # an instance of XMLElement: <railml>

dfinfra = getInfra(xroot);
# CSV.write("data/infra.csv", dfinfra);

dfvehicles = getVehicles(xroot);
# CSV.write("data/vehicles.csv", dfvehicles);

dflocos = getLocos(xroot, dfvehicles);
# CSV.write("data/locos.csv", dflocos);


timetable = xroot["timetable"][1];

categories = timetable["categories"][1]["category"];
trainparts = timetable["trainParts"][1]["trainPart"];
trains = timetable["trains"][1]["train"];

dfcat = DataFrame(id=String[], code=String[], name=String[], usage=String[]);
for cat in categories
    D = attributes_dict(cat);
    push!(dfcat, (D["id"], D["code"], D["name"], D["trainUsage"]));
end

maxparts = 0;
for t in trains
    maxparts = max(maxparts, length(t["trainPartSequence"]));
end
println(maxparts);

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
# CSV.write("data/trains.csv", dftrain);

# for part in trainparts
#     id = attribute(part, "id");
#     catref = attribute(part, "categoryRef");
#     formref = attribute(part["formationTT"][1], "formationRef");
#     ops = part["ocpsTT"][1]["ocpTT"];
#     for op in ops
#         oref = attribute(op, "ocpRef");
#         type = attribute(op, "ocpType");
#         times = op["times"];
#         for t in times
#             scope = attribute(t, "scope");
#             if scope == "actual"
#                 realtime = 
#             scope = attribute(t, "scope");
#             .........
#     end
# end


println();

# <ocpTT ocpRef="ocp_ZL_S12_2021-12-11_230000" sequence="8" ocpType="pass">
#   <times scope="actual" arrival="14:12:32" arrivalDay="0" departure="14:12:32" departureDay="0"/>
#   <times scope="scheduled" arrival="14:12:54" arrivalDay="0" departure="14:12:54" departureDay="0"/>
#   <times scope="published" arrival="14:12:54" arrivalDay="0" departure="14:12:54" departureDay="0"/>
# </ocpTT>
# <ocpTT ocpRef="ocp_ZL_H1_2021-12-11_230000" sequence="9" ocpType="stop">
#   <times scope="actual" arrival="14:13:08" arrivalDay="0" departure="14:13:38" departureDay="0"/>
#   <times scope="scheduled" arrival="14:13:30" arrivalDay="0" departure="14:14:00" departureDay="0"/>
#   <times scope="published" arrival="14:13:30" arrivalDay="0" departure="14:14:00" departureDay="0"/>
# </ocpTT>


# p=[ string("pippo",i) => String[] for i in a];
# insertcols!(D, p...);

# # traverse all its child nodes and print element names
# for c in child_nodes(xroot)  # c is an instance of XMLNode
#     println(nodetype(c))
#     if is_elementnode(c)
#         e = XMLElement(c)  # this makes an XMLElement instance
#         println(name(e))
#     end
# end


# free(xdoc);

