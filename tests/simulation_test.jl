using Test

@testset "Simulation" begin

    fname="./run/out"
    out=read(fname, String)

    # original_stdout=stdout
    # (out,_)=redirect_stdout()
    #
    # cmd=`julia --project=training_env --code-coverage ./simulation/main.jl --ini ./tests/data/par_test.ini ">" ./run/out` #
    # run(cmd)
    #
    # new_stdout=readline(out)
    # redirect_stdout(original_stdout);

    str="Total delay at the end of simulation is 42\n"

    println(out)
    println(str)

    @test out==str
end
