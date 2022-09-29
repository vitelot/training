using LightXML, DataFrames, CSV;

thevalue(x,s) = attribute(get_elements_by_tagname(x, s)[1], "Value");
theoptionalvalue(x,s) = attribute(get_elements_by_tagname(x, s)[1], "OptionalValue");
thelength(x,s) = length(get_elements_by_tagname(x, s));

function xml2soldf(file::String)
    data = parse_file(file);
    xroot = root(data);
    sol = get_elements_by_tagname(xroot, "SectionOfLine");

    data = xroot = nothing;

    UString = Union{String, Nothing};

    df = DataFrame(id=UString[], tracks=Int[]);

    for s in sol
        bst1 = thevalue(s,"SOLOPStart")[3:end] |> uppercase;
        bst2 = thevalue(s,"SOLOPEnd")[3:end] |> uppercase;
        ntracks = thelength(s,"SOLTrack");

        blk = string(bst1,"-",bst2);
        push!(df, (blk, ntracks));
    end

    sort(df, :id)
end

df = xml2soldf("RINF-SOL.xml");
CSV.write("blocks.csv", df);

function xml2soldfl(file::String)
    data = parse_file(file);
    xroot = root(data);
    sol = get_elements_by_tagname(xroot, "SectionOfLine");

    data = xroot = nothing;

    UString = Union{String, Nothing};

    df = DataFrame(block=UString[], line=UString[],
                    ntracks=Int[], length=Int[]);

    for s in sol
        line = thevalue(s, "SOLLineIdentification");
        bst1 = thevalue(s,"SOLOPStart")[3:end];
        bst2 = thevalue(s,"SOLOPEnd")[3:end];
        ntracks = thelength(s,"SOLTrack");
        len = thevalue(s, "SOLLength") |> x->replace(x,","=>"") |> x->parse(Int,x);

        block = string(bst1,"-",bst2) |> uppercase;
        block = replace(block, r"[ _]+" => "");
        push!(df, (block, line, ntracks, len));
    end

    sort(df, :block)
end

df = xml2soldfl("RINF-SOL.xml");
CSV.write("rinf-blocksl.csv", df);

function xml2optdf(file::String)
    data = parse_file(file);
    xroot = root(data);
    op = get_elements_by_tagname(xroot, "OperationalPoint");

    data = xroot = nothing;
    UString = Union{String, Nothing};

    df = DataFrame(id=UString[], name=UString[], type=UString[], ntracks=Int[], nsidings=Int[]);

    for o in op;

        id = thevalue(o, "UniqueOPID")[3:end] |> uppercase;
        opname = thevalue(o,"OPName"); #attribute(get_elements_by_tagname(o, "OPName")[1], "Value");
        optype = theoptionalvalue(o, "OPType");
        ntracks = thelength(o, "OPTrack");
        nsidings = thelength(o, "OPSiding");

        push!(df, (id,opname,optype,ntracks,nsidings))
    end
    sort(df, :id)
end

df = xml2optdf("RINF-SOL.xml");
CSV.write("rinf-OperationalPoints.csv", df);
