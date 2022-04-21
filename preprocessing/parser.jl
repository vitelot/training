using ArgParse

function parse_commandline()
    s = ArgParseSettings()

    @add_arg_table s begin

        "--date", "-d"
            help = "date we want to extrapolate the timetable"
            arg_type = String
            default = "25.03.19"

        "--file", "-f"
            help = "file with the timetable to process"
            arg_type = String
            default = ""

        "--source_data_path"
            help = "source of the pad zuglauf..."
            arg_type = String
            default = "../data/hidden_data/"

        "--exo_delays"
            help = "Number of file with exo delays to be created."
            arg_type = Int
            default = 0

    end

    return parse_args(s)
end
