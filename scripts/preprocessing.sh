#! /bin/sh

echo "#####################################"
echo "######## PREPROCESSING ##############"
echo "#####################################\n"

year=$1

if [ "$year" = "" ]
then
    year="2018"
fi

cd ../preprocessing

echo "\nExtracting blocks and operational points details from RINF data"
julia scan-RINF-SOL-xml.jl

echo "\nExtracting the scheduled timetable from the XML files EBU of year $year"
julia scanxml.jl $year
