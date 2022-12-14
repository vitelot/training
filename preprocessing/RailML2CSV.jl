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
# print its name
println(name(xroot))  # this should print: bookstore

dfinfra = getInfra(xroot);
# CSV.write("data/infra.csv", dfinfra);

dfvehicles = getVehicles(xroot);
# CSV.write("data/vehicles.csv", dfvehicles);

dflocos = getLocos(xroot, dfvehicles);
# CSV.write("data/locos.csv", dflocos);



# # traverse all its child nodes and print element names
# for c in child_nodes(xroot)  # c is an instance of XMLNode
#     println(nodetype(c))
#     if is_elementnode(c)
#         e = XMLElement(c)  # this makes an XMLElement instance
#         println(name(e))
#     end
# end


free(xdoc);

