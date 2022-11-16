
module MyDates

using Dates;

"""
    dateToSeconds(d::AbstractString)::Int

Given a string in the format "yyyy-mm-dd HH:MM:SS"
returns the number of seconds elapsed from the epoch
"""
function dateToSeconds(d::AbstractString)::Int
            dt::DateTime = Dates.DateTime(d, "dd.mm.yyyy HH:MM:SS")
            return Int(floor(datetime2unix(dt)))
            #return (Dates.hour(dt)*60+Dates.minute(dt))*60+Dates.second(dt)
end
"""
    dateToSeconds(d::Int)::Int

If the input is an Int do nothing
assuming that it is already the number of seconds elapsed from the epoch
"""
function dateToSeconds(d::Int)::Int
          return d
end
"""
    dateToSeconds(d::Missing)::Missing

If the input is missing do nothing
"""
function dateToSeconds(d::Missing)::Missing
            return missing
end

export dateToSeconds;

end