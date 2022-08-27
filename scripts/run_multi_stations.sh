echo "Running multiple simulations with injected delays and with fixed double directions at stations."

cd ../simulation
echo "julia --project=../environment main.jl --inject_delays --multi_simulation"
julia --project=../environment main.jl --inject_delays --multi_simulation
