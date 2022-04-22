echo "Running the simulation with no flags."
echo "If the default initialization file par.ini is not found, a new one is created."
cd ../simulation

echo "julia --project=../training_env main.jl"
julia --project=../training_env main.jl
