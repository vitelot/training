#! /bin/sh

echo "This script is disabled"

exit

echo "#####################################"
echo "############ CONFIGURE ##############"
echo "#####################################\n"

cd ../configuration

echo "julia --project=../environment configure.jl $@"
julia --project=../environment configure.jl $@


# https://www.shellscript.sh/
