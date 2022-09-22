#! /bin/tcsh
set file = $1
echo working on $file

awk -F, 'OFS="," {print $3 $4, $5, $8,$9}' $file | tr -d '"' > out

echo 'results in "out" file'
