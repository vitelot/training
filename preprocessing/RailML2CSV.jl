using CSV, DataFrames, LightXML;

cd("preprocessing");

UString = Union{String,Missing};

xdoc = parse_file("data/railml_2022-08-05.xml");

# get the root element
xroot = root(xdoc);  # an instance of XMLElement: <railml>
# print its name
println(name(xroot))  # this should print: bookstore

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

CSV.write("data/infra.csv", df);

# traverse all its child nodes and print element names
for c in child_nodes(xroot)  # c is an instance of XMLNode
    println(nodetype(c))
    if is_elementnode(c)
        e = XMLElement(c)  # this makes an XMLElement instance
        println(name(e))
    end
end


free(xdoc);

