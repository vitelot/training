#! /bin/sh

day=$1

if [ "$day" = "" ]
then
    day="25.03.19"
fi

echo "\n#####################################"
echo "You need to have the folder data/hidden_data to run."
echo "We are going to simulate the default date 25.03.19"
echo "unless you specify a different day in the command line.\n"

echo "Starting the preprocessing phase."
cd ../preprocessing

echo "julia --project=../environment preprocessing.jl -d $day"
julia --project=../environment preprocessing.jl -d $day

echo "\n#####################################\n"
echo "Fixing the infrastructure."
cd ../simulation

echo "julia --project=../environment main.jl --catch_conflict"
julia --project=../environment main.jl --catch_conflict

mv -f ../data/simulation_data/blocks_catch.csv ../data/simulation_data/blocks.csv

echo "\n#####################################\n"
echo "Starting the simulation phase."
cd ../simulation

echo "julia --project=../environment main.jl"
julia --project=../environment main.jl
