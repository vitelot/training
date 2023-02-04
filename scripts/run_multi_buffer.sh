#! /bin/sh

for a in 000 030 060 090 120 150 180
    do
        echo "Using a buffer of $a seconds"
        ./r --inject_delays  -t ../simulation/data/timetable_buffer$a.csv > ../simulation/data/buffer$a.out
        mv -f ../simulation/data/timetable_simulation.csv ../simulation/data/timetable_simulation-$a.csv
    done
