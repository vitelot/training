@info "Loading libraries";

using CSV, DataFrames;
import Dates: unix2datetime, Date, Time;

UString = Union{String,Missing};

mutable struct Opoint
    name::UString
    db640::UString
    code::UString
    desc::UString
    coord::UString
end

function outputRailML(outfilename::String, df_timetable::DataFrame, df_ops::DataFrame, df_loko::DataFrame)

    # export RailML version 2.3
    @info "Exporting RailML version 2.3";

    name, extension = splitext(outfilename);
    outfilename = string(name,"_v23",extension);

    @info("The timetable generated by the simulation is printed on file \"$outfilename\"");


    open(outfilename, "w") do OUT
        pout(n::Int,x::String) = println(OUT, "   "^n,x);
        pout(x::String) = println(OUT, x);

        Ops = Dict{String, Opoint}();
        for r in eachrow(df_ops)
            id = replace(r.name, r"[ _]+" => "");
            Ops[id] = Opoint(r.name, r.db640, string(r.code), r.description, r.coordinates);
        end


        # preamble
        pout("""<?xml version="1.0" ?>""");
        pout("""<railml version="2.3" xmlns="http://www.railml.org/schemas/2016" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.railml.org/schemas/2016 ../schema/railML.xsd">""");
        pout(1, "<metadata>");
        pout(1, "</metadata>");
        
        # infra
        pout(1, """<infrastructure id="IS_01" name="infrastructure" timetableRef="TT_01" rollingstockRef="RS_01">""")
        pout(2, "<operationControlPoints>");

            # <ocp id="ocp_WATS13_2021-12-11_230000" code="91036" name="WATS13" description="Sbl Wat 1" parentOcpRef="ocp_WATS13_2021-12-11_230000">
			# 	<propOperational operationalType="blockSignal"/>
			# 	<area name="Niederösterreich"/>
			# 	<geoCoord coord="48.203507 15.663307"/>
			# 	<designator register="DB640" entry="Wat S13" startDate="2021-12-11" endDate="2022-12-10"/>
			# 	<designator register="PLC" entry="91036" startDate="2021-12-11" endDate="2022-12-10"/>
			# </ocp>

        # Operation Control Points (ocp) loop
        for o in unique(df_timetable.opid)
            haskey(Ops,o) || @info "\tKey $o is missing in the operational point file. Filling with defaults.";
            op = get(Ops, o, Opoint(o, o, o, o, ""));
            db640 = op.db640;
            code = op.code;
            desc = op.desc;
            coord = op.coord;

            pout(3,"<ocp id=\"ocp_$o\" code=\"$code\" name=\"$db640\" description=\"$desc\">"); # parentOcpRef=\"ocp_$o\">");
            pout(4, "<geoCoord coord=\"$coord\"/>");
            pout(3,"</ocp>");
        end

        pout(2, "</operationControlPoints>");
        pout(1, "</infrastructure>");

        # rolling stock
        trains = unique(df_timetable.trainid);

        pout(1, "<rollingstock id=\"RS_01\" name=\"rollingstock\" infrastructureRef=\"IS_01\" timetableRef=\"TT_01\">");

        pout(2, "<vehicles>");
        
        dl = select(df_loko, r"loco");
        # aggregate all locos into one vector
        vehicles = unique(dropmissing(stack(dl,:)).value);
        for v in vehicles
            # println(v)

            ss = split(v,".");
            if length(ss) == 1
                id = ss[1]; nr = "";
            else
                (id, nr) = ss;
            end

            vid = "$id$nr"; 
            pout(3, "<vehicle id=\"veh_$vid\" code=\"$vid\" name=\"$v\">");
            pout(4, "<classification>");
            pout(5, "<operator operatorClass=\"$id\"/>");
            pout(4, "</classification>");
            pout(3,"</vehicle>");
        end
        pout(2, "</vehicles>");

        pout(2, "<formations>");
        
        gd = groupby(df_loko, :trainid);

        for g in gd
            trainid = g.trainid[1];
            trainid ∈ trains || continue; # skip if not in the timetable
            (cat,nr) = split(trainid,"_", limit=2);
            pout(3, "<formation id=\"for_$nr\">");
            
            pout(4, "<trainOrder>");
            on = 1;
            locos = stack(g, r"loco");
            for l in locos.value
                ismissing(l) && continue;
                vid = replace(l, "." => "");
                pout(5, "<vehicleRef orderNumber=\"$on\" vehicleRef=\"veh_$vid\"/>");
                on += 1;
            end
            on == 1 && @info "Empty formation for_$nr for train $trainid";

            pout(4, "</trainOrder>");

            pout(3, "</formation>");
        end

        pout(2, "</formations>");

        pout(1, "</rollingstock>");

        # timetable
        pout(1, "<timetable id=\"TT_01\" name=\"timetable\" infrastructureRef=\"IS_01\" rollingstockRef=\"RS_01\">")
        pout(2, "<timetablePeriods>");
        (mintime, maxtime) = extrema(df_timetable.t_scheduled);
        minday = Date(unix2datetime(mintime));
        starttime = Time(unix2datetime(mintime));
        maxday = Date(unix2datetime(maxtime));
        endtime = Time(unix2datetime(maxtime));
        pout(3, """<timetablePeriod id="ttp_01" name="Betriebstag $minday" startDate="$minday" endDate="$maxday" startTime="$starttime" endTime="$endtime"/>""")
        pout(2, "</timetablePeriods>");
        
        pout(2, "<categories>");        
        # trains = unique(df_timetable.trainid);
        cats = [split(x,"_")[1] for x in trains];
        for c in unique(cats)
            pout(3, """<category id="cat_$(c)_$(c)" code="$c" name="$c" trainUsage="passenger"/>""")
        end
        pout(2, "</categories>");
        
        # train parts
        pout(2, "<trainParts>");
        
        gd = groupby(df_timetable, :trainid);
        islastarrival = false;
        arrivalsched = 0;
        arrivalreal = 0;
        arrivalschedday = 0;
        arrivalrealday = 0;

        for dfunsorted in gd
            df = sort(dfunsorted, [:t_scheduled]);
            trainid = df.trainid[1];
            (cat,nr) = split(trainid,"_", limit=2);
            pout(3,"<trainPart id=\"trp_$nr\" processStatus=\"actual\" categoryRef=\"cat_$(cat)_$(cat)\">")
            pout(4,"<formationTT formationRef=\"for_$nr\" weight=\"\" length=\"\" speed=\"\"/>")
            pout(4, "<ocpsTT>");
            seq = 0;
            for r in eachrow(df)
                kind = r.kind;
                kind == "P" && continue;
                opid = r.opid; 
                sched = r.t_scheduled;
                real = r.t_real;
                seq += 1;
                # dayidsched = ifelse( Date(unix2datetime(sched))==minday, 0, 1); 
                # dayidreal =  ifelse( Date(unix2datetime(real))==minday, 0, 1); 
                dayidsched = (Date(unix2datetime(sched))-minday).value;
                dayidreal  = (Date(unix2datetime(real))-minday).value;
                sched = unix2datetime(r.t_scheduled) |> Time;
                real = unix2datetime(r.t_real) |> Time;
                if kind == "b"
                    kind = "begin";
                    pout(5,"<ocpTT ocpRef=\"ocp_$opid\" sequence=\"$seq\" ocpType=\"$kind\">")
                    # pout(6,"<times scope=\"actual\" departure=\"$real\" departureDay=\"$dayidreal\"/>")
                    pout(6,"<times scope=\"scheduled\" departure=\"$sched\" departureDay=\"$dayidsched\"/>")
                elseif kind == "e"
                    kind = "end";
                    pout(5,"<ocpTT ocpRef=\"ocp_$opid\" sequence=\"$seq\" ocpType=\"$kind\">")
                    # pout(6,"<times scope=\"actual\" arrival=\"$real\" arrivalDay=\"$dayidreal\"/>")
                    pout(6,"<times scope=\"scheduled\" arrival=\"$sched\" arrivalDay=\"$dayidsched\"/>")
                elseif kind == "p"
                    kind = "pass";  
                    pout(5,"<ocpTT ocpRef=\"ocp_$opid\" sequence=\"$seq\" ocpType=\"$kind\">")
                    # pout(6,"<times scope=\"actual\" arrival=\"$real\" arrivalDay=\"$dayidreal\" departure=\"$real\" departureDay=\"$dayidreal\"/>")
                    pout(6,"<times scope=\"scheduled\" arrival=\"$sched\" arrivalDay=\"$dayidsched\" departure=\"$sched\" departureDay=\"$dayidsched\"/>")
                elseif kind == "a"
                    seq -= 1;
                    arrivalsched = sched;
                    arrivalreal = real;
                    arrivalschedday = dayidsched;
                    arrivalrealday = dayidreal;
                    islastarrival = true;
                    continue;
                elseif kind == "d"
                    kind = "stop";
                    if !islastarrival
                        if seq == 1
                            arrivalsched = sched;
                            arrivalreal = real;
                            arrivalschedday = dayidsched;
                            arrivalrealday = dayidreal;
                        else
                            @warn "Departure without arrival for $trainid in $opid at sequence $seq.";
                        end
                    end
                    pout(5,"<ocpTT ocpRef=\"ocp_$opid\" sequence=\"$seq\" ocpType=\"$kind\">")
                    # pout(6,"<times scope=\"actual\" arrival=\"$arrivalreal\" arrivalDay=\"$arrivalrealday\" departure=\"$real\" departureDay=\"$dayidreal\"/>")
                    pout(6,"<times scope=\"scheduled\" arrival=\"$arrivalsched\" arrivalDay=\"$arrivalschedday\" departure=\"$sched\" departureDay=\"$dayidsched\"/>")
                    islastarrival = false; 
                end
                
                pout(5,"</ocpTT>"); 
                
            end
            pout(4,"</ocpsTT>");
            pout(3,"</trainPart>");
        end


        pout(2, "</trainParts>");

        # trains
        pout(2, "<trains>");

        for t in trains
            (cat,nr) = split(t,"_", limit=2);
            pout(3, "<train id=\"train_$nr\" type=\"operational\" trainNumber=\"$nr\" processStatus=\"actual\">");
            pout(4, "<trainPartSequence sequence=\"1\">");
            pout(5, "<trainPartRef ref=\"trp_$nr\"/>");
            pout(4, "</trainPartSequence>");
            pout(3, "</train>");
        end
        # <train id="train_19209_99837" type="operational" trainNumber="99837" processStatus="actual">
        #            <trainPartSequence sequence="1">
        #                          <trainPartRef ref="trp_19209_99837_PK_3_2"/>
        #                          <brakeUsage brakeType="none" regularBrakePercentage="69"/>
        #            </trainPartSequence>
        #  </train>

        pout(2, "</trains>");
        pout(1, "</timetable>");
        
        # end
        pout("</railml>");
    end
end

function outputRailMLv22(outfilename::String, df_timetable::DataFrame, df_ops::DataFrame, df_loko::DataFrame)

    # export RailML version 2.2

    @info "Exporting RailML version 2.2";

    name, extension = splitext(outfilename);
    outfilename = string(name,"_v22",extension);

    @info("The timetable generated by the simulation is printed on file \"$outfilename\"");

    
    open(outfilename, "w") do OUT
        pout(n::Int,x::String) = println(OUT, "   "^n,x);
        pout(x::String) = println(OUT, x);

        Ops = Dict{String, Opoint}();
        for r in eachrow(df_ops)
            id = replace(r.name, r"[ _]+" => "");
            Ops[id] = Opoint(r.name, r.db640, string(r.code), r.description, r.coordinates);
        end


        # preamble
        pout("""<railml xmlns="http://www.railml.org/schemas/2013" xmlns:fbs="http://schema.fbsbahn.de/2.x/fbs_railml_extension" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" version="2.2" xsi:schemaLocation="http://www.railml.org/schemas/2013 http://www.railml.org/schemas/2013/railML-2.2/railML.xsd http://schema.fbsbahn.de/2.x/fbs_railml_extension http://schema.fbsbahn.de/2.x/fbs_railml_extension.xsd">""");
        pout(1, "<metadata>");
        pout(1, "</metadata>");
        
        # infra
        pout(1, """<infrastructure id="infra_ZugDB_PR">""");

        pout(2, "<tracks>");
        pout(2, "</tracks>");

        pout(2, "<trackGroups>");
        pout(2, "</trackGroups>");

        pout(2, "<operationControlPoints>");

        # <ocp id="ocp_Wat_S13" name="Sbl Wat 1" type="operationalName" code="Wat S13">
        #   <geoCoord coord="48.2035 15.6633" epsgCode="4258" />
        #   <designator register="DB640" entry="Wat S13" />
        #   <designator register="PLC" entry="91036" />
        # </ocp>

        # Operation Control Points (ocp) loop
        for o in unique(df_timetable.opid)
            haskey(Ops,o) || @info "\tKey $o is missing in the operational point file. Filling with defaults.";
            op = get(Ops, o, Opoint(o, o, o, o, ""));
            db640 = op.db640;
            code = op.code;
            desc = op.desc; #replace(op.desc, "&" => "and");
            coord = op.coord;

            pout(3,"<ocp id=\"ocp_$o\" name=\"$desc\" type=\"operationalName\" code=\"$db640\">");
            if !ismissing(coord) && !isempty(coord)
                pout(4, "<geoCoord coord=\"$coord\"/>");
            end
            pout(4, "<designator register=\"DB640\" entry=\"$db640\"/>");
            pout(4, "<designator register=\"PLC\" entry=\"$code\"/>");
            pout(3,"</ocp>");
        end

        pout(2, "</operationControlPoints>");
        pout(1, "</infrastructure>");

        # rolling stock
        trains = unique(df_timetable.trainid);

        pout(1, """<rollingstock id="rs_ZugDB_PR">""");

        pout(2, "<vehicles>");
        
        dl = select(df_loko, r"loco");
        # aggregate all locos into one vector
        vehicles = unique(dropmissing(stack(dl,:)).value);
        vehicles = unique([split(x,".")[1] for x in vehicles]);

        # <vehicle id="veh_.2068.1" name="2068" axleSequence="" numberDrivenAxles="4" length="13.770000" speed="100" bruttoWeight="72000" nettoWeight="72000" nettoAdhesionWeight="72000">
        #     <classification>
        #         <manufacturer manufacturerType="2068" />
        #         <operator operatorName="ÖBB" operatorClass="2068" />
        #     </classification>
        #     <wagon>
        #         <passenger drivingCab="0" />
        #     </wagon>
        # </vehicle>

        for v in vehicles
            # println(v)

            pout(3, "<vehicle id=\"veh_$v\" name=\"$v\">");
            pout(4, "<classification>");
            pout(5, "<manufacturer manufacturerType=\"$v\" />");
            pout(5, "<operator operatorName=\"ÖBB\" operatorClass=\"$v\" />");
            pout(4, "</classification>");
            pout(3,"</vehicle>");
        end
        pout(2, "</vehicles>");

        pout(2, "<formations>");
        
        gd = groupby(df_loko, :trainid);

        for g in gd
            trainid = g.trainid[1];
            trainid ∈ trains || continue; # skip if not in the timetable
            (cat,nr) = split(trainid,"_", limit=2);
            on = 1;
            all_locos = dropmissing(stack(g, r"loco")).value;
            # locos = filter(!ismissing, all_locos.value);
            locos = [split(x,".")[1] for x in all_locos];
            jl = join(locos,",");
            
            pout(3, "<formation id=\"for_$nr\" name=\"$jl\">");
            
            pout(4, "<trainOrder>");
            for l in locos
                # ismissing(l) && continue;
                # vid = split(l,".")[1];
                pout(5, "<vehicleRef orderNumber=\"$on\" vehicleRef=\"veh_$l\"/>");
                on += 1;
            end
            on == 1 && @info "Empty formation for_$nr for train $trainid";

            pout(4, "</trainOrder>");

            pout(3, "</formation>");
        end

        pout(2, "</formations>");

        pout(1, "</rollingstock>");

        # timetable
        pout(1, """  <timetable infrastructureRef="infra_ZugDB_PR" rollingstockRef="tt_ZugDB_PR" id="tt_ZugDB_PR">""");
        # pout(1, "<timetable id=\"TT_01\" name=\"timetable\" infrastructureRef=\"IS_01\" rollingstockRef=\"RS_01\">")
        pout(2, "<timetablePeriods>");
        (mintime, maxtime) = extrema(df_timetable.t_scheduled);
        minday = Date(unix2datetime(mintime));
        starttime = Time(unix2datetime(mintime));
        maxday = Date(unix2datetime(maxtime));
        endtime = Time(unix2datetime(maxtime));

        pout(3, """<timetablePeriod id="ttp_01" name="Betriebstag $minday" startDate="$minday" endDate="$maxday" startTime="$starttime" endTime="$endtime"/>""")
        pout(2, "</timetablePeriods>");
        
        pout(2, "<categories>");        
        # trains = unique(df_timetable.trainid);
        cats = [split(x,"_")[1] for x in trains];
        for c in unique(cats)
            pout(3, """<category id="cat_$(c)_$(c)" code="$c" name="$c" trainUsage="passenger"/>""")
        end
        pout(2, "</categories>");
        
        # train parts

        # <trainPart id="tp_45260.1.261371.opp_261371" code="45260" trainNumber="45260" processStatus="toBeOrdered" timetablePeriodRef="ttp_2021_2022" categoryRef="cat_261371">
        #     <formationTT formationRef="fmt_2558" weight="90000" timetableLoad="0" length="18.980000" speed="160" />
        #     <operatingPeriodRef ref="opp_261371" />
        #     <ocpsTT>


        pout(2, "<trainParts>");
        
        gd = groupby(df_timetable, :trainid);
        islastarrival = false;
        arrivalsched = 0;
        arrivalreal = 0;
        arrivalschedday = 0;
        arrivalrealday = 0;

        for dfunsorted in gd
            df = sort(dfunsorted, [:t_scheduled]);
            trainid = df.trainid[1];
            (cat,nr) = split(trainid,"_", limit=2);
            pout(3,"<trainPart id=\"trp_$nr\" code=\"$nr\" trainNumber=\"$nr\" processStatus=\"actual\" categoryRef=\"cat_$(cat)_$(cat)\">")
            pout(4,"<formationTT formationRef=\"for_$nr\" weight=\"10\" length=\"100\" speed=\"300\"/>")
            pout(4, "<ocpsTT>");
            seq = 0;
            for r in eachrow(df)
                kind = r.kind;
                kind == "P" && continue;
                opid = r.opid; 
                sched = r.t_scheduled;
                real = r.t_real;
                seq += 1;
                # dayidsched = ifelse( Date(unix2datetime(sched))==minday, 0, 1); 
                # dayidreal =  ifelse( Date(unix2datetime(real))==minday, 0, 1); 
                dayidsched = (Date(unix2datetime(sched))-minday).value;
                dayidreal  = (Date(unix2datetime(real))-minday).value;
                sched = unix2datetime(r.t_scheduled) |> Time;
                real = unix2datetime(r.t_real) |> Time;

                #         <ocpTT sequence="1" ocpRef="ocp_83TS_CM" remarks="ZUGB" ocpType="pass">
                #             <times departure="18:55:00" departureDay="0" scope="scheduled" />
                #         </ocpTT>

                if kind == "b"
                    kind = "begin";
                    pout(5,"<ocpTT ocpRef=\"ocp_$opid\" sequence=\"$seq\" ocpType=\"$kind\">")
                    # pout(6,"<times scope=\"actual\" departure=\"$real\" departureDay=\"$dayidreal\"/>")
                    pout(6,"<times scope=\"scheduled\" departure=\"$sched\" departureDay=\"$dayidsched\"/>")
                elseif kind == "e"
                    kind = "end";
                    pout(5,"<ocpTT ocpRef=\"ocp_$opid\" sequence=\"$seq\" ocpType=\"$kind\">")
                    # pout(6,"<times scope=\"actual\" arrival=\"$real\" arrivalDay=\"$dayidreal\"/>")
                    pout(6,"<times scope=\"scheduled\" arrival=\"$sched\" arrivalDay=\"$dayidsched\"/>")
                elseif kind == "p"
                    kind = "pass";  
                    pout(5,"<ocpTT ocpRef=\"ocp_$opid\" sequence=\"$seq\" ocpType=\"$kind\">")
                    # pout(6,"<times scope=\"actual\" arrival=\"$real\" arrivalDay=\"$dayidreal\" departure=\"$real\" departureDay=\"$dayidreal\"/>")
                    pout(6,"<times scope=\"scheduled\" arrival=\"$sched\" arrivalDay=\"$dayidsched\" departure=\"$sched\" departureDay=\"$dayidsched\"/>")
                elseif kind == "a"
                    seq -= 1;
                    arrivalsched = sched;
                    arrivalreal = real;
                    arrivalschedday = dayidsched;
                    arrivalrealday = dayidreal;
                    islastarrival = true;
                    continue;
                elseif kind == "d"
                    kind = "stop";
                    if !islastarrival
                        if seq == 1
                            arrivalsched = sched;
                            arrivalreal = real;
                            arrivalschedday = dayidsched;
                            arrivalrealday = dayidreal;
                        else
                            @warn "Departure without arrival for $trainid in $opid at sequence $seq.";
                        end
                    end
                    pout(5,"<ocpTT ocpRef=\"ocp_$opid\" sequence=\"$seq\" ocpType=\"$kind\">")
                    # pout(6,"<times scope=\"actual\" arrival=\"$arrivalreal\" arrivalDay=\"$arrivalrealday\" departure=\"$real\" departureDay=\"$dayidreal\"/>")
                    pout(6,"<times scope=\"scheduled\" arrival=\"$arrivalsched\" arrivalDay=\"$arrivalschedday\" departure=\"$sched\" departureDay=\"$dayidsched\"/>")
                    islastarrival = false; 
                end
                
                pout(5,"</ocpTT>"); 
                
            end
            pout(4,"</ocpsTT>");
            pout(3,"</trainPart>");
        end


        pout(2, "</trainParts>");

        # trains
        pout(2, "<trains>");

        # <train id="tro_240869" type="operational" trainNumber="46667" scope="primary" name="" remarks="flex">
        #     <trainPartSequence sequence="1">
        #         <trainPartRef ref="tp_46667.1.240869.opp_240869" position="1" />
        #     </trainPartSequence>
        # </train>

        for t in trains
            (cat,nr) = split(t,"_", limit=2);
            pout(3, "<train id=\"train_$nr\" type=\"operational\" trainNumber=\"$nr\" processStatus=\"actual\">");
            pout(4, "<trainPartSequence sequence=\"1\">");
            pout(5, "<trainPartRef ref=\"trp_$nr\"/>");
            pout(4, "</trainPartSequence>");
            pout(3, "</train>");
        end

        pout(2, "</trains>");
        pout(1, "</timetable>");
        
        # end
        pout("</railml>");
    end
end

function readCSV(timetablefile::String)::DataFrame
    if !isfile(timetablefile)
        @warn "Input file $timetablefile does not exist. Nothing to do."
        return;
    end
    return CSV.read(timetablefile, comment="#", DataFrame);
end

function csv2railml(version="2.3")
    timetablefile = "data/timetable.csv";
    railmlfile = splitext(timetablefile)[1] * ".railml";

    @info "Processing file $timetablefile";

    dftbl = readCSV(timetablefile);
    dftbl.trainid = replace.(dftbl.trainid, "+"=>"-");

    dfops = CSV.read("data/OperationalPoints.csv", comment="#", DataFrame);
    dfops.description = replace.(dfops.description, "&"=>"and");

    dfloko = CSV.read("data/traction_units.csv", types=String, comment="#", DataFrame);
    dfloko.trainid = replace.(dfloko.trainid, "+"=>"-");
    
    if version == "2.3"
        outputRailML(railmlfile, dftbl, dfops, dfloko);
    elseif version == "2.2"
        outputRailMLv22(railmlfile, dftbl, dfops, dfloko);
    else
        @error "Unknown RailML version $version requested.";
    end

    nothing;
end

csv2railml("2.2")
# csv2railml("2.3")
