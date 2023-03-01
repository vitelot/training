using CSV, DataFrames, DelimitedFiles;
include("../configuration/MyGraphs.jl");
using .MyGraphs;

# load the graph
G=Main.MyGraphs.loadGraph("../simulation/data/blocks.csv", type="directed");
# find the paths until 80 op away by using DFS
Paths = Main.MyGraphs.findAllSequences(G, "NB", "G", 80);
# 
sort!(Paths, by=length);
# save for inspection
writedlm("./data/Paths.txt", Paths);
# save the one that looks ok
CSV.write("./data/NB-G.csv", DataFrame(bst=Paths[3]));