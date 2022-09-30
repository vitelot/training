## Description

This folder contains scripts that work out the raw data files turning them into
input files for the configuration procedure.

The raw data files are: 

1. `RINF` (Register of INFrastructure) data. These data can be retrieved from the [RINF web site](https://rinf.era.europa.eu/rinf/). After registering, you can retrieve infrastructure data for the whole Austria and export them in a XML file. We use RINF data to establish the line id, number of tracks and length of the section of lines (blocks) in the railway system. The script taking care of this is ```scan-RINF-SOL-xml```.

2. `Yearly schedules`. These data are provided by OeBB, are not public, and cover the scheduled timetables of all the trains travelling in Austria. These data are in a xml format. We use these data as a reference to build the timetables. The scripts taking care of this are ```scan.xml``` and ```findblocks_from_xml.jl```.

3. `Daily transits`. These data are not public and contain the effective operations in one day. Some trains travel in one day even if they have not been scheduled. Some others are canceled. These data account for all of that. Unfortunately, there are some holes due to minor recording infrastructure failures, so that they must be processed by using the information collected from the RINF and the yearly schedules. The script taking care of these data is ```compose.jl```.