#! /bin/sh

for a in 000 030 060 090 120 150 180
    do
        echo "Using a buffer of $a seconds"
        r --multi_stations --inject_delays  -t ../data/simulation_data/timetable_buffer$a.csv > ../data/simulation_data/buffer$a.out
        mv -f ../data/simulation_data/timetable_simulation.csv ../data/simulation_data/timetable_simulation-$a.csv
    done
