using ArgParse

function parse_commandline()
    s = ArgParseSettings()

    @add_arg_table s begin

        "--date", "-d"
            help = "date we want to extrapolate the timetable"
            arg_type = String
            default = "25.03.19"

        "--source_data_path"
            help = "source of the pad zuglauf..."
            arg_type = String
            default = "../../hidden_data/"



    end

    return parse_args(s)
end
