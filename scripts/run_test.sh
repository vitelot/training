echo "Running a test using a proxy timetable and a fake railway structure"
cd ../
julia --project=training_env ./simulation/main.jl --ini ./tests/data/par_test_default.ini
