using LightXML, DataFrames, CSV;
import Base.uppercase;

uppercase(nothing) = nothing;

function xml2df(file::String)
    data = parse_file(file);

    # save_file(data, "dataf.xml") # save in a readable format

    xroot=root(data);
    timetable = get_elements_by_tagname(xroot,     "timetable");
    trains = get_elements_by_tagname(timetable[1], "trains");
    train = get_elements_by_tagname(trains[1],     "train");

    data = timetable = trains = xroot = nothing;

    UString = Union{String, Nothing};

    df = DataFrame(train=UString[],
                    bst=UString[], bstname=UString[],
                    direction=UString[], section=UString[],
                    distance=UString[], km=UString[],
                    arrival=UString[], departure=UString[],
                    type=UString[]);

    for t in train

        kind =   attribute(t, "kind");
        number = attribute(t, "trainNumber");
        train = string(kind,"_",number);

        ttes = get_elements_by_tagname(t,      "timetableEntries");
        tte =  get_elements_by_tagname(ttes[1],"timetableEntry");

        for bst in tte

            departure = attribute(bst, "departure");
            arrival =   attribute(bst, "arrival");
            posID =     attribute(bst, "posID") |> uppercase;
            posName =   attribute(bst, "posName");
            type =      attribute(bst, "type");
            distance =  attribute(bst, "distance");
            km =        attribute(bst, "kmPos");

            # isnothing(posID) || (posID = replace(posID, r"[ _]+" => ""););

            section = get_elements_by_tagname(bst, "section");
            if length(section)>0
                dir =       attribute(section[1], "direction");
                secid =     attribute(section[1], "sectionID");
            else
                dir = secid = nothing;
            end
            if length(section)>1
                @warn "more sections found in train $train at $bst";
            end

            push!(df, (train, posID, posName, dir, secid, distance, km, arrival, departure, type));

            #println("$kind$number,$arrival,$departure,$posID,$posName");
        end
    end
    df
end

"""
    convertAll(outfile = "xml-timetable.csv"; raw=true)

Parse all XML files starting with "EBU_Reise" and extract a timetable.
"""
function convertAll(outfile = "xml-timetable.csv"; raw=true)
    if isfile(outfile)
        println("Outfile \"$outfile\" is already present. Doing nothing.")
        return;
    end

    filelist = filter(x->startswith(x,"EBU_Reise"), readdir());
    # c = 0;
    f1 = popfirst!(filelist);
    df = xml2df(f1);

    for f in filelist
        # c += 1;
        append!(df, xml2df(f));
    end

    if !raw
        # remove lines with no operational point (OP)
        dropmissing!(df, :bst);
        # remove lines with OP of type KM + number
        filter!(x->!startswith(x.bst,"KM "), df);
        # remove OP with no convetional name and of type Ixxx (OP at border)
        filter!(x->!occursin(r"^I\d+$", x.bst), df);
        # remove spaces and underscores from OP names
        transform!(df, :bst => ByRow(x->replace(x, r"[ _]+" => "")) => :bst);
    end

    CSV.write(outfile, df, transform=(col, val)->val==nothing ? missing : val);

    nothing
end

convertAll("xml-2018.csv", raw = false);

# EXAMPLE OF XML FILE
# <timetableEntry arrival="06:59:30" brakeRatio="89" departure="07:00:30" distance="3892" kmPos="9.4" kmSys="58" optSpeed="50" posID="Ott" posName="Ottensheim" radioChannel="-ZLF A-77-" speed="55" type="stop">
#   <section direction="2" section2ID="258" sectionID="25801" trackID="1"/>
# </timetableEntry>
