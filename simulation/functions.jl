
"""
functions.jl : contains the definition of functions that are NOT needed for initializing our system on the infrastructure
"""

function read_non_hidden_files(repo::AbstractString)::Vector{String}
    filelist = readdir(repo, join=true);
    filter!(!isdir, filelist);
    filelist = basename.(filelist);

    # ignore files starting with . and _
    return filter(x->!startswith(x, r"\.|_"), filelist)
end

"""
If test mode is enabled, runs speed test without printing simulation results on std out
"""
function runTest(RN::Network, FL::Fleet)

#    print("\nPerforming speed test with no output. Please be patient.\r")
    # if Opt["test"] == 2
    #     print("Using @btime ...\r")
    #     @btime simulation($RN, $FL)
    # else
        @time simulation(RN, FL)
        # @info("Macro @time was used.\n")
    # end
end

# """ranged random number generator"""
# function myRand(min::Float64, max::Float64)::Float64
#     return rand(range(min,length=20,stop=max))
# end

"""
 function that calculates the status of the simulation as a string of blocks
 and their occupancies in terms of train id;
 has also a hashing function to try to speed up
"""
function netStatus(RN::Network; hashing::Bool=false)

    BK = RN.blocks;
    ST = RN.stations;

    status = "";
    for blk in values(BK) # we might need a sort here because the order of keys may change
        status *= "$(blk.id):$(blk.train)\n\n";
    end
    status *= "###############################\n\n";
    for station in values(ST) # we might need a sort here because the order of keys may change
        status *= "$(station.id):$(station.train)\n\n";
    end

    #hashing && return sha256(status) |> bytes2hex; #sha256()->hexadecimal; bytes2hex(sha256())->string
    hashing && return hash(status);

    return status
end

"""
Resets the dynamical variables of trains in case of multiple simulation runs
"""
function resetSimulation(FL::Fleet)#,RN::Network
    Opt["print_flow"] && @info "Resetting Fleet dynamical properties before restarting."
    for Train in values(FL.train)
        Train.dyn = DynTrain(0,"","");
    end
end

import Base.sort!
sort!(v::Vector{Transit}) = sort!(v, by=x->x.duetime) # usage: FL.train["SB29541"].schedule

import Base.issorted
issorted(v::Vector{Transit}) = issorted(v, by=x->x.duetime) # usage: FL.train["SB29541"].schedule

function outputRailML(outfilename::String, df_timetable::DataFrame)

    @info "RailML export not implemented yet.";
    # return;

    @info("The timetable generated by the simulation is printed on file \"$outfilename\"");

    open(outfilename, "w") do OUT
        pout(x) = println(OUT, x);
        # preamble
        pout( 
        """
        <?xml version="1.0" ?>
        <railml version="2.3" xmlns="http://www.railml.org/schemas/2016" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.railml.org/schemas/2016 ../schema/railML.xsd">
        \t<metadata>
        \t</metadata>"""
        );

# infra
        pout(
            """\t<infrastructure id="IS_01" name="infrastructure" timetableRef="TT_01" rollingstockRef="RS_01">
                \t\t<operationControlPoints>"""
                );

            # <ocp id="ocp_WATS13_2021-12-11_230000" code="91036" name="WATS13" description="Sbl Wat 1" parentOcpRef="ocp_WATS13_2021-12-11_230000">
			# 	<propOperational operationalType="blockSignal"/>
			# 	<area name="Niederösterreich"/>
			# 	<geoCoord coord="48.203507 15.663307"/>
			# 	<designator register="DB640" entry="Wat S13" startDate="2021-12-11" endDate="2022-12-10"/>
			# 	<designator register="PLC" entry="91036" startDate="2021-12-11" endDate="2022-12-10"/>
			# </ocp>

        # ocp loop
        for o in unique(df_timetable.opid)
            pout(
            "\
                \t\t\t<ocp id=\"ocp_$o\" code=\"9999\" name=\"$o\" description=\"$o\" parentOcpRef=\"ocp_$o\">\
            ");

            pout("\t\t\t</ocp>");
        end

        pout(
        """\t\t</operationControlPoints>
            \t</infrastructure>"""
        );


# end
        pout("</railml>");
    end
end