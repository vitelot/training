using Test

@testset "Simulation" begin

    cmd=`julia --project=${{github.workspace}}/training_env ${{github.workspace}}/simulation/main.jl ./tests/data/par_test.ini`
    original_stdout=stdout
    (out,_)=redirect_stdout()

    run(cmd)
    new_stdout=readline(out)
    redirect_stdout(original_stdout);
    str="Total delay at the end of simulation is 42"

    @test new_stdout==str
end
