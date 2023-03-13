using ArgParse;

function parse_commandline()
    s = ArgParseSettings();

    @add_arg_table s begin

        "--date", "-d"
            help = "Date from which we want to extract the timetable."
            arg_type = String
            default = "09.05.18"

        "--file", "-f"
            help = "PAD file with the timetable to process."
            arg_type = String
            default = ""

        "--source_data_path"
            help = "Source of the PAD timetable files."
            arg_type = String
            default = "../preprocessing/data/"

        "--target_data_path"
            help = "Folder to write processed data for the simulation."
            arg_type = String
            default = "../simulation/data/"

        "--select_line"
            help = "Select part of the railway network by loading the list of ops from files in the source data path folder.\n\
            E.g., --select_line NB-MI loads the file NB-MI.csv"
            arg_type = String
            default = ""

            # "--exo_delays"
        #     help = "Number of files with exo delays to be created."
        #     arg_type = Int
        #     default = 0

        # "--use_real_time"
        #     help = "Use the real time column of the PAD timetable instead of the scheduled time."
        #     action = :store_true

        "--pad_schedule"
            help = "Use the scheduled time in the PAD file instead of the scheduled time found in XML."
            action = :store_true

            # "--split_transits"
        #     help = "Splits a Durchfahrt into two events by adding a durchfahrt_out few seconds later."
        #     action = :store_true

        "--rotations"
            help = "Create a file with train dependencies. One train cannot start if the other has not arrived yet."
            action = :store_true

        "--cut_day"
            help = "Restrict the timetable to one day ignoring trains over midnight."
            action = :store_true

        # "--buffering"
        #     help = "Number of seconds to increase the buffering time of trains at selected stations stations. The list of trains and stations is in the code not in a file yet."
        #     arg_type = Int
        #     default = 0

    end

    return parse_args(s)
end
