echo "Running the simulation with flags $@"
#echo "If the default initialization file par.ini is not found, a new one is created."
cd ../simulation

echo "julia --project=../environment main.jl $@"
julia --project=../environment main.jl $@
