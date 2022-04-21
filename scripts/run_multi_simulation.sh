echo "Running multiple simulations with injected delays."
echo "The par.ini configuration file has to be edited and the option imposed_delay_repo_path"
echo "has to contain the name of the folder with the delay files."
cd ../simulation

echo "julia --project=../training_env main.jl --inject_delays --multi_simulation"

julia --project=../training_env main.jl --inject_delays --multi_simulation
