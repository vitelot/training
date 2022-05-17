#! /bin/sh
for a in 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28
	do
		p --split_transits --use_real_time -d $a.10.19
		r --multi_stations --catch_conflict
	done
