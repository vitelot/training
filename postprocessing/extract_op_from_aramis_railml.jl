using CSV, DataFrames;

file = "data/railml_2022-08-05.xml";
# pwd()
L = readlines(file);
filter!(x->occursin("<ocp id=",x), L);
df = DataFrame(name=String[], code=String[], description=String[]);
for l in L
    code=name=desc="";
    if occursin("code=", l);
        m = match(r"code=\\\"(.*?)\\\"", l);
        code = m.captures[1];
    end
    if occursin("name=", l);
        m = match(r"name=\\\"(.*?)\\\"", l);
        name = m.captures[1];
    end
    if occursin("description=", l);
        m = match(r"description=\\\"(.*?)\\\"", l);
        desc = m.captures[1];
    end
    # m = match(r"code=\\\"(?<code>.*)\\\".*name=\\\"(?<name>.+)\\\".+description=\\\"(?<desc>.+?)\\\"", l);
    # println("### $l")
    # code, name, desc = m;
    push!(df, (name, code, desc));
end

CSV.write("data/OperationalPoints.csv", sort(df, :name));