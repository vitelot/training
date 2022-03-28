include("extern.jl")
include("initialize.jl")
include("parameters.jl")
include("functions.jl")
include("simulation.jl")
include("parser.jl")




# macro catch_conflict(RN,FL,parsed_args)
#
#
#     ex=quote
#
#         while true
#             try
#                 println("ENTERED IN THE META")
#                 #one or multiple simulations
#                 if ($(parsed_args)["multi_simulation"])
#                     # multiple_sim($(esc(RN)), $(esc(FL)))
#                 else
#                     one_sim($RN, $FL)
#                 end
#                 #insert here function for saving the blocks list
#                 break
#             catch err
#
#                 if isa(err, KeyError)
#
#
#
#                     println("KeyError occurring : $(err.key)")
#
#                     name=err.key
#                     b = Block(
#                             name,
#                             # i,
#                             1,
#                             0,
#                             Set{String}()
#                     )
#
#                     $(RN).nb += 1
#
#                     $(RN).blocks[name]=b
#
#                     println("Added to RN.blocks the block:",$(RN).blocks[err.key])
#
#                     resetSimulation($FL);
#                     resetDynblock($RN);
#
#
#
#                 else
#
#                     train=(err.trainid)
#                     block=err.block
#                     println($(RN).blocks[block])
#
#                     ntracks=$(RN).blocks[block].tracks
#                     # $(esc(RN)).blocks[block]=Block(block,ntracks+1,0,Set{String}())
#                     $(RN).blocks[block].tracks=ntracks+1
#                     $(RN).blocks[block].nt=0
#                     $(RN).blocks[block].train=Set{String}()
#
#                     println($(RN).blocks[block])
#
#                     if $(RN).blocks["BU-BUN"].tracks > 3
#                         break
#                     end
#
#
#
#                     resetSimulation($FL);
#                     resetDynblock($RN);
#                 end
#
#             end
#         end
#     end
#
#
#     @show ex
#     return esc(ex)
# end

function catch_conflict(RN,FL,parsed_args)

    while true
        try

            #one or multiple simulations
            if (parsed_args["multi_simulation"])
                # multiple_sim($(esc(RN)), $(esc(FL)))
            else
                one_sim(RN, FL)
            end

            #insert here function for saving the blocks list
            _,date=split(Opt["timetable_file"],"-")
            out_file_name="../data/simulation_data/blocks_catch-$date.csv"
            print_railway(RN,out_file_name)
            break
        catch err

            if isa(err, KeyError)

                println("KeyError occurring : $(err.key)")

                name=err.key
                b = Block(
                        name,
                        # i,
                        1,
                        0,
                        Set{String}()
                )

                RN.nb += 1

                RN.blocks[name]=b

                println("Added to RN.blocks the block:",RN.blocks[err.key])

                resetSimulation(FL);
                resetDynblock(RN);

            else

                train=(err.trainid)
                block=err.block
                println(RN.blocks[block])

                ntracks=RN.blocks[block].tracks
                # $(esc(RN)).blocks[block]=Block(block,ntracks+1,0,Set{String}())
                RN.blocks[block].tracks=ntracks+1
                RN.blocks[block].nt=0
                RN.blocks[block].train=Set{String}()

                println(RN.blocks[block])

                resetSimulation(FL);
                resetDynblock(RN);
            end



        end
    end

end

function main()


    #CLI parser
    parsed_args = parse_commandline()

    #load parsed_args["ini"] file infos
    loadOptions(parsed_args);

    #load the railway net
    RN = loadInfrastructure();
    FL = loadFleet();



    if parsed_args["catch_conflict_flag"]==false

        #one or multiple simulations
        if parsed_args["multi_simulation"]
            multiple_sim(RN, FL)
        else
            one_sim(RN, FL)
        end

    else
        catch_conflict(RN,FL,parsed_args)

    end


end
















function one_sim(RN::Network, FL::Fleet)

    #inserting delays from data/delays/ repo..
    if isdir(Opt["imposed_delay_repo_path"])
         delays_array,number_simulations = loadDelays();
         #imposing first file delay, simulation_id=1
         imposeDelays(FL,delays_array,1)
     end

    Opt["print_flow"] && println("##################################################################")
    Opt["print_flow"] && println("Starting simulation")

    if Opt["simulate"]

        Opt["test"]>0 && runTest(RN,FL)

        simulation(RN, FL)
    else
        return (RN,FL)
    end

    nothing
end











function multiple_sim(RN::Network, FL::Fleet)

    if isdir(Opt["imposed_delay_repo_path"])
        delays_array,number_simulations = loadDelays()
    else
        Opt["print_notifications"] && println(stderr,"Running multiple_sim() without imposing delays file,no sense. Running simple simulation.")
        delays_array=[]
        number_simulations=1
    end

    for simulation_id in 1:number_simulations

        Opt["print_flow"] && println("##################################################################")
        Opt["print_flow"] && println("Starting simulation number $simulation_id")
        Opt["print_notifications"] && println(stderr,"Starting simulation number $simulation_id.")

        isempty(delays_array) || imposeDelays(FL,delays_array,simulation_id)

        if Opt["simulate"]
            simulation(RN, FL)  && (println("returned 1 , restarting");)
        else
            return (RN,FL)
        end

    end
    nothing
end



main()
