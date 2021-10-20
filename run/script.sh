#! /bin/bash -f

train='SB22674'
delays=(1 2 4 8 16 32 64 128)

cd ..

for delay in ${delays[@]}; do
        rm -f imposed_delay.csv
        echo "starting with delay ${delay}"
        echo "trainid,opid,kind,delay" >> imposed_delay.csv
        echo "$train,NB,Beginn,$delay" >> imposed_delay.csv
        #echo ${delay}
        #cd ../..
        julia main.jl

done

#  rm input
#  echo ${n_c} >> input
#  echo ${solid_cutoff} >> input
#  time  ./program
#  sleep 5
#done

#while read train; do
#        rm input
#        echo "trainid,opid,kind,delay" >> input
#        echo "'$train',NB,Beginn,$delay" >> input
#        sleep 5
#
#done <"trainlist.txt"



#for n_c in 10.0 20.0 30.0 40.0 50.0 60.0 70.0 80.0 90.0 100.0 110.0 120.0 130.0 140.0 150.0 160.0 170.0 180.0 190.0 200.0; do
#  rm input
#  echo ${n_c} >> input
#  echo ${solid_cutoff} >> input
#  time  ./program
#  sleep 5
#done

exit
