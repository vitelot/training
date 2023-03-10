using CSV, DataFrames, LightXML;

UString = Union{String,Missing};

# pwd()
function lineScan(file::String)::DataFrame
    L = readlines(file);

    @info "Extracting information on operational points";

    filter!(x->occursin("<ocp id=",x), L);
    df = DataFrame(name=String[], code=String[], description=String[]);
    for l in L
        code=name=desc="";
        if occursin("code=", l);
            m = match(r"code=\\\"(.*?)\\\"", l);
            code = m.captures[1];
        end
        if occursin("name=", l);
            m = match(r"name=\\\"(.*?)\\\"", l);
            name = m.captures[1];
        end
        if occursin("description=", l);
            m = match(r"description=\\\"(.*?)\\\"", l);
            desc = m.captures[1];
        end
        # m = match(r"code=\\\"(?<code>.*)\\\".*name=\\\"(?<name>.+)\\\".+description=\\\"(?<desc>.+?)\\\"", l);
        # println("### $l")
        # code, name, desc = m;
        push!(df, (name, code, desc));
    end

    @info "\tFound $(length(unique(df.name))) operational points";

    return df;
end


function getInfra(infile::String)::DataFrame
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

    @info "Reading file $infile";
    xdoc = parse_file(infile);

    # get the root element
    xroot = root(xdoc);  # an instance of XMLElement: <railml>
    
    @info "Extracting information on operational points";

    Infra = xroot["infrastructure"];
    Ops = Infra[1]["operationControlPoints"][1]["ocp"];

    df = DataFrame(name=UString[], db640=UString[], code=UString[], description=UString[], coordinates=UString[]);

    for o in Ops
        id = attribute(o, "id");
        db640 = "";
        name = attribute(o, "name");
        code = attribute(o, "code");
        isnothing(code) && (code = missing);

        descr = attribute(o, "description");
        # println(id);
        coord = length(o["geoCoord"]) == 0 ? missing : attribute(o["geoCoord"][1], "coord"); 
        designators = o["designator"];
        for d in designators
            if attribute(d, "register") == "DB640";
                db640 = attribute(d, "entry");
                break;
            end
        end
        # println( (name,db640,code,descr,coord) )
        push!(df, (name,db640,code,descr,coord));
    end

    @info "\tFound $(length(unique(df.name))) operational points";

    return df;
end

pwd()
cd("postprocessing")

file = "data/railml_2022-08-05.xml";

# df = lineScan(file);
# CSV.write("data/OperationalPoints-small.csv", sort(df, :name));

df = getInfra(file);
CSV.write("data/OperationalPoints.csv", sort(df, :name));
