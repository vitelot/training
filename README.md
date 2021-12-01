# training

## procedure:
* extract data/data.zip
* in preprocessing/ , run `./run_preprocessing.sh`: this will move the unzipped data into the correct directory(data/simulation_data/), create /data/simulation_data/trains_beginning.ini for the starting of trains, create preprocessing/trainIni.in if not present (selection of trains to be delayed), and create the delay files in data/delays/
* to run the simulation, in /run/ , run `./run.sh`
