echo "Running a test using a proxy timetable and a fake railway structure."
cd ../
echo "Initializing the simulation."

echo "julia --project=environment ./simulation/main.jl --ini ./tests/data/par_test_default.ini"
julia --project=environment ./simulation/main.jl --ini ./tests/data/par_test_default.ini
