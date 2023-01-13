"""
Scans the xml EBU files to output the scheduled timetable in file xml-year.csv
Available years are 2018 and 2019 only.
"""

@info "Loading libraries";

using LightXML, DataFrames, CSV;
import Base.uppercase;

inputdir = "./data";
outputdir = "./data";

uppercase(nothing) = nothing;

"""
    xml2df(file::String)::DataFrame

Parses the XML file with scheduled timetable and returns a dataframe with
train, posID, posName, dir, secid, distance, km, arrival, departure, type
"""
function xml2df(file::String)::DataFrame
    data = parse_file(file);
    
    # save_file(data, "dataf.xml") # save in a readable format

    xroot=root(data);
    timetable = get_elements_by_tagname(xroot,     "timetable");
    trains = get_elements_by_tagname(timetable[1], "trains");
    train = get_elements_by_tagname(trains[1],     "train");

    # free(data);
    data = timetable = trains = xroot = nothing;

    UString = Union{String, Nothing};

    df = DataFrame(train=UString[],
                    bst=UString[], bstname=UString[],
                    direction=UString[], line=UString[],
                    distance=UString[], km=UString[],
                    arrival=UString[], departure=UString[],
                    type=UString[]);

    for t in train
        # @show t;

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
    
    filelist = filter(x->startswith(x,"$inputdir/EBU_Reise"), readdir(inputdir, join=true));

    f1 = popfirst!(filelist);    
    df = xml2df(f1);

    for f in filelist
        println("Processing file $f");
        append!(df, xml2df(f));
    end

    if !raw
        @info "The resulting timetable will be cleaned. \
        Set raw=true if you need the raw one.
            We remove lines with empty operational point,\
            those with signals at km x,
            the pseudo operational points right after the border.";
  
            
        # list of stations out of Austria
        tabu = ["PA", "BA", "BC", "BE", "HE", "JS", "L", "MFL", "MT", "MW", "PAMK2", "SC", "SOP", "TBV", "SCH1", "GH"];
  
        # remove lines with no operational point (OP)
        filter!(x->!isnothing(x.bst), df);
        # remove lines with OP of type KM + number
        filter!(x->!startswith(x.bst,"KM "), df);
        # remove OP with no conventional name and of type Ixxx (OP at border)
        filter!(x->!occursin(r"^I\d+$", x.bst), df);
        # remove spaces and underscores from OP names
        transform!(df, :bst => ByRow(x->replace(x, r"[ _]+" => "")) => :bst);
        # remove tabu` stations
        filter!(x->x.bst ∉ tabu, df);
        # remove OP at the border
        filter!(x->!startswith(x.bstname,"Staatsgrenze"), df);

    end

    @info "Saving the schedule into file \"$outfile\"";
    CSV.write(outfile, df, transform=(col, val)->val==nothing ? missing : val);

    nothing
end

if length(ARGS) > 0
    year = ARGS[1];
else
    year = "2018";
end

availableyears = ["2018", "2019"];
if year ∈ availableyears
    
    @info "Scanning year $year";

    outfile = "$outputdir/xml-$year.csv";
    inputdir = inputdir * "/$year";

    convertAll(outfile, raw = false);
else
    @info "Only the years 2018 and 2019 are available. I do not know anything about \"$year\".";
end


# EXAMPLE OF XML FILE
# <timetableEntry arrival="06:59:30" brakeRatio="89" departure="07:00:30" distance="3892" kmPos="9.4" kmSys="58" optSpeed="50" posID="Ott" posName="Ottensheim" radioChannel="-ZLF A-77-" speed="55" type="stop">
#   <section direction="2" section2ID="258" sectionID="25801" trackID="1"/>
# </timetableEntry>
