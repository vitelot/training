#! /bin/sh

echo "#####################################"
echo "############ CONFIGURE ##############"
echo "#####################################\n"

cd ../configuration

echo "julia --project=../environment configure.jl $@"
julia --project=../environment configure.jl $@


# https://www.shellscript.sh/
