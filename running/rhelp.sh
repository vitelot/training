#! /bin/sh

file="rhelp.txt"

if [ ! -e $file ]; then
  julia --project=../environment ../simulation/main.jl -h > $file
else
  cat $file
fi
