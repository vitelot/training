#! /bin/tcsh
set file = $1
echo working on $file

echo "day,train,bst,code,kind,duetime,realtime" > _tmp
awk -F, 'OFS="," {print $1,$3 $4,$5,$7,$8,$9,$10}' $file | tr -d '"' >> _tmp

grep -v Betriebstag _tmp > out
rm -f _tmp

echo 'results in "out" file'



# rename!(df,:Istzeit => :realtime)
# rename!(df,:Betriebstag => :day)
# rename!(df,:Zugnr => :treno)
# rename!(df,:"Sollzeit R" => :duetime)
# rename!(df,:"Zuglaufmodus Code" => :code)
