## Description

This folder contains scripts that work out the raw data files turning them into
input files for the configuration procedure.

The raw data files are: 

1. `RINF` (Register of INFrastructure) data. These data can be retrieved from the [RINF web site](https://rinf.era.europa.eu/rinf/). After registering, you can retrieve infrastructure data for the whole Austria and export them in a XML file. We use RINF data to establish the line id, number of tracks and length of the section of lines (blocks) in the railway system. The script taking care of this is ```scan-RINF-SOL-xml.jl```.

2. `Yearly schedules`. These data are provided by OeBB, are not public, and cover the scheduled timetables of all the trains travelling in Austria. These data are in a xml format. We use these data as a reference to build the timetables. The script taking care of this is ```scanxml.jl```.

3. `RailML ARAMIS data`. These data are not public and contain the effective operations in one day.