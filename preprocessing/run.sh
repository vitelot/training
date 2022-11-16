# extract blocks and operational points details from RINF data
julia scan-RINF-SOL-xml.jl
# extract the scheduled timetable from the XML files EBU
julia scanxml.jl 2018
