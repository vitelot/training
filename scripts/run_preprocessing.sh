echo "Starting the preprocessing phase."
echo "You can specify a particular date other than the default 25.03.19 with the -d option. "
cd ../preprocessing
julia --project=../training_env preprocessing.jl # -d 25.03.19
