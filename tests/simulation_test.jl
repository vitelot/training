using Test

@testset "Simulation" begin


    original_stdout=stdout
    (out,_)=redirect_stdout()

    cmd=`julia --project=training_env --code-coverage ./simulation/main.jl ./tests/data/par_test.ini`
    run(cmd)

    new_stdout=readline(out)
    redirect_stdout(original_stdout);

    str="Total delay at the end of simulation is 42"

    @test new_stdout==str
end
