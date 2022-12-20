## Description

This folder contains scripts that work out the preprocessed data turning them into input files for the simulation.

The following data must be provided:

1. `Daily transits`. These data are not public and contain the effective operations in one day. Some trains travel in one day even if they have not been scheduled. Some others are canceled. These data account for all of that. Unfortunately, there are some holes due to minor recording infrastructure failures, so that they must be processed by using the information collected from the RINF and the yearly schedules. The script taking care of these data is ```configure.jl```.
These data can be extracted from ARAMIS RailML files in the preprocessing folder.