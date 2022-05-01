echo "Running multiple simulations with injected exogenous delays."
echo "The par.ini configuration file has to be edited and the option imposed_delay_repo_path"
echo "has to contain the name of the folder with the delay files."
echo "The default day 25.03.19 is used."

cd ../preprocessing
echo "julia --project=../training_env preprocessing.jl --exo_delays 90"
julia --project=../training_env preprocessing.jl --exo_delays 90

cd ../simulation
echo "julia --project=../training_env main.jl --inject_delays --multi_simulation"
julia --project=../training_env main.jl --inject_delays --multi_simulation
