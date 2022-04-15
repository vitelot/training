#! /bin/sh

day=$1

if [ "$day" = "" ]
then
    day="25.03.19"
fi

echo "#####################################"
echo "You can specify a particular date other than the default 25.03.19 . "
echo "For example: ./run_preprocessing 04.02.19\n"
echo "Starting the preprocessing phase."
echo "#####################################\n"

cd ../preprocessing

echo "julia --project=../training_env preprocessing.jl -d $day"
julia --project=../training_env preprocessing.jl -d $day


# https://www.shellscript.sh/
