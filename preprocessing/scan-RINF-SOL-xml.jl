"""
Takes the file RINF-SOL.xml as input and generates the files
   - rinf-blocks.csv with block information: op1, op2, line, ntracks, length;
   - rinf-OperationalPoints.csv with operational poin information: id, name, type, ntracks, nsidings
"""

@info "Loading libraries";
using LightXML, DataFrames, CSV;

inputdir = "./data";
outputdir = "./data";

thevalue(x,s) = attribute(get_elements_by_tagname(x, s)[1], "Value");
theoptionalvalue(x,s) = attribute(get_elements_by_tagname(x, s)[1], "OptionalValue");
thelength(x,s) = length(get_elements_by_tagname(x, s));

# function xml2soldf(file::String)
#     data = parse_file(file);
#     xroot = root(data);
#     sol = get_elements_by_tagname(xroot, "SectionOfLine");

#     data = xroot = nothing;

#     UString = Union{String, Nothing};

#     df = DataFrame(id=UString[], tracks=Int[]);

#     for s in sol
#         bst1 = thevalue(s,"SOLOPStart")[3:end] |> uppercase;
#         bst2 = thevalue(s,"SOLOPEnd")[3:end] |> uppercase;
#         ntracks = thelength(s,"SOLTrack");

#         blk = string(bst1,"-",bst2);
#         push!(df, (blk, ntracks));
#     end

#     sort(df, :id)
# end

# df = xml2soldf("RINF-SOL.xml");
# CSV.write("blocks.csv", df);

function xml2soldfl(file::String)
    data = parse_file(file);
    xroot = root(data);
    sol = get_elements_by_tagname(xroot, "SectionOfLine");

    data = xroot = nothing;

    UString = Union{String, Nothing};

    df = DataFrame(bst1=UString[], bst2=UString[],
                    line=UString[],
                    ntracks=Int[], 
                    length=Int[]);

    for s in sol
        line = thevalue(s, "SOLLineIdentification");
        bst1 = thevalue(s,"SOLOPStart") |> uppercase |> x->replace(x,r"^AT"=>""); # removes the initial AT prefix
        bst2 = thevalue(s,"SOLOPEnd")   |> uppercase |> x->replace(x,r"^AT"=>"");
        ntracks = thelength(s,"SOLTrack");
        len = thevalue(s, "SOLLength") |> x->replace(x,","=>"") |> x->parse(Int,x);

        # block = string(bst1,"-",bst2) |> uppercase;
        # block = replace(block, r"[ _]+" => "");

        # resolving Homonym "BG" and "B  G"
        bst1 = replace(bst1, r"^B +G" => "BXG");
        bst2 = replace(bst2, r"^B +G" => "BXG");

        # removing spaces
        bst1 = replace(bst1, r"[ _]+" => "");
        bst2 = replace(bst2, r"[ _]+" => "");
        push!(df, (bst1,bst2, line, ntracks, len));
    end

    sort(df, :bst1)
end

function xml2optdf(file::String)
    data = parse_file(file);
    xroot = root(data);
    op = get_elements_by_tagname(xroot, "OperationalPoint");

    data = xroot = nothing;
    UString = Union{String, Nothing};

    df = DataFrame(id=UString[], name=UString[], type=UString[], ntracks=Int[], nsidings=Int[]);

    for o in op;

        id = thevalue(o, "UniqueOPID")[3:end] |> uppercase;
        id = replace(id, r"^B +G"=>"BXG");
        id = replace(id, r"[ ]+"=>"");
        opname = thevalue(o,"OPName"); #attribute(get_elements_by_tagname(o, "OPName")[1], "Value");
        optype = theoptionalvalue(o, "OPType");
        ntracks = thelength(o, "OPTrack");
        nsidings = thelength(o, "OPSiding");

        push!(df, (id,opname,optype,ntracks,nsidings))
    end
    sort(df, :id)
end

@info "Scanning...";

df = xml2soldfl("$inputdir/RINF-SOL.xml");
file = "$outputdir/rinf-blocks.csv";
CSV.write(file, df);
@info "Section of line data saved in file \"$file\"";

df = xml2optdf("$inputdir/RINF-SOL.xml");
file = "$outputdir/rinf-OperationalPoints.csv";
CSV.write(file, df);
@info "Operational points data saved in file \"$file\"";
