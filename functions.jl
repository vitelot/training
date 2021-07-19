function dateToSeconds(d::String)
"""
Given a string in the format "yyyy-mm-dd HH:MM:SS"
returns the number of seconds elapsed from midnight
"""
    dt=Dates.DateTime(d, "yyyy-mm-dd HH:MM:SS")
    return (Dates.hour(dt)*60+Dates.minute(dt))*60+Dates.second(dt)
end
