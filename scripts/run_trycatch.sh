echo "The simulation will try to infer the infrastructure based on the trains circulating."
cd ../simulation

echo "julia --project=../training_env main.jl --catch_conflict_flag"
julia --project=../training_env main.jl --catch_conflict_flag
