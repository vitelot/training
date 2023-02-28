module MyGraphs

using DataFrames, CSV;

struct Node
    id::String
    neighbors::Vector{String}
end

struct Edge
    id::String
    from::Node
    to::Node
    length::Int
    capacity::Int
end

mutable struct Graph
    type::String
    nodes::Int
    edges::Int
    nodelist::Dict{String,Node}
    edgelist::Dict{String,Edge}
end

"""
    loadGraph(file::AbstractString; type="undirected", removespace=false)::Graph

Reads a file with edge lists, one per line, and generates a graph structure.
The file can contain more than two columns. Only the first two containing the 
nodes id of the link are considered. If the first column contains links in 
the form A-B, then only the first column is read.
"""
function loadGraph(file::AbstractString; type="undirected", removespaces=false)::Graph
    df = CSV.File(file, comment="#") |> DataFrame;
    loadGraph(df, type=type, removespaces=removespaces)
end

function loadGraph(df::DataFrame; type="undirected", removespaces=false)::Graph
    
    if occursin("-", df[1,1])
        select!(df, 1 => ByRow(x->split(x,"-")) => [:bst1, :bst2]);
    end

    nnodes = nedges = 0;
    G = Graph(type,
                nnodes, nedges,
                Dict{String,Node}(), # nodelist
                Dict{String,Edge}()  # edgelist
            );

    for i in 1:nrow(df)
        (b1, b2) = df[i,1:2]; 
        len = nt = 0;
        if removespaces
            b1 = replace(b1, r"[ _]+" =>"");
            b2 = replace(b2, r"[ _]+" =>"");
        end
        for b in [b1,b2]
            if !haskey(G.nodelist, b)
                nnodes += 1;
                n = Node(b, String[]);
                G.nodelist[b] = n;
            end
        end
        edgeid = "$b1-$b2";
        if !haskey(G.edgelist, edgeid)
            edge = Edge(edgeid, G.nodelist[b1], G.nodelist[b2],
                        len, nt);
            G.edgelist[edgeid] = edge;
            push!(G.nodelist[b1].neighbors, b2);
            nedges += 1;
        end
        if G.type == "undirected"

            edgeid = "$b2-$b1";
            if !haskey(G.edgelist, edgeid)
                edge = Edge(edgeid, G.nodelist[b2], G.nodelist[b1],
                            len, nt);
                G.edgelist[edgeid] = edge;
                push!(G.nodelist[b2].neighbors, b1);
            end
        end
    end
    G.nodes = nnodes;
    G.edges = nedges;

    return(G);
end

"""
    BFS(G::Graph, from::AbstractString, to::AbstractString)::Vector{String}

Perform a BFS on a graph structure.
Returns (one of) the shortest paths from node "from" to node "to" as a vector of strings.
Returns one element ["from"] if the nodes are not connected. 
Low level function. Please use findSequence().
"""
function BFS(G::Graph, from::AbstractString, to::AbstractString)::Vector{String}
    Path = Dict{String, Vector{String}}()
    visited = Set{String}();
    queue = [from];
    push!(visited, from);
    Path[from] = String[];
    while length(queue)>0
        s = popfirst!(queue);
        #println("$s");
        for b in G.nodelist[s].neighbors
            if b ∉ visited
                # get!(Path, b, String[]);
                # append!(Path[b], [s], Path[s]);
                Path[b] = [Path[s]; b];
                push!(visited,b);
                push!(queue, b);
                b==to && break;
            end
        end
    end
    get!(Path,to,[]); #op are not connected
    return [from; Path[to]]
end


"""
    findSequence(G::Graph, from::AbstractString, to::AbstractString)::Vector{String}

Perform a BFS on a graph structure.
Returns (one of) the shortest paths from node "from" to node "to" as a vector of strings.
Returns one element vector ["from"] if the nodes are not connected. 
"""
function findSequence(G::Graph, from::AbstractString, to::AbstractString)::Vector{String}
    if !haskey(G.nodelist, from)
        println("Node \"$from\" is not in the node list. Quitting.");
        exit(1);
    end
    if !haskey(G.nodelist, to)
        println("Node \"$to\" is not in the node list. Quitting.");
        exit(1);
    end
    if haskey(G.edgelist, "$from-$to")
        edge = G.edgelist["$from-$to"];
        return [from, to]; #(edge.id, edge.length);
    end
    BFS(G, from, to)

end

"""
    findAllSequences(G::Graph, from::AbstractString, to::AbstractString)::Vector{Vector{String}}

Perform a DFS on a graph structure.
Returns the paths connecting node "from" to node "to" as a vector of vectors of strings.
Returns an empty vector if the nodes are not connected. 
"""
function findAllSequences(G::Graph, from::AbstractString, to::AbstractString)::Vector{Vector{String}}
    if !haskey(G.nodelist, from)
        println("Node \"$from\" is not in the node list. Quitting.");
        exit(1);
    end
    if !haskey(G.nodelist, to)
        println("Node \"$to\" is not in the node list. Quitting.");
        exit(1);
    end
    # Path = Dict{String, Vector{String}}();
    Path = String[];
    nonvisited = Set{String}(keys(G.nodelist));
    Paths = Vector{Vector{String}}();

    function DFS(G::Graph, from::AbstractString, to::AbstractString)::Nothing
        from ∉ nonvisited && return;
        length(Path) > 50 && return;

        pop!(nonvisited, from);
        push!(Path, from);
        if from == to
            push!(Paths, copy(Path));
            push!(nonvisited, from);
            pop!(Path);
            return;
        end
        for b in G.nodelist[from].neighbors
            DFS(G,b,to);
        end
        pop!(Path);
        push!(nonvisited, from);
        return;
    end

    DFS(G, from, to);
    return Paths;

end

function isnode(G::Graph, s::AbstractString)::Bool
    return haskey(G.nodelist, s);
end

export Graph, loadGraph, findSequence, findAllSequences;
end