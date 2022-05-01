#! /bin/tcsh
set file = $1
echo working on $file
set day = $file:s/timetable_//:r
set outfile = $file:r.out.csv

echo "day,train,bst,code,kind,duetime,realtime" > _tmp
awk -F, -v DAY=$day 'OFS="," {print DAY,$1,$2,"Z","KIND",$3,$4}' $file | tr -d '"' >> _tmp

grep -v t_real _tmp > $outfile
rm -f _tmp

echo "results in file $outfile"



# rename!(df,:Istzeit => :realtime)
# rename!(df,:Betriebstag => :day)
# rename!(df,:Zugnr => :treno)
# rename!(df,:"Sollzeit R" => :duetime)
# rename!(df,:"Zuglaufmodus Code" => :code)
