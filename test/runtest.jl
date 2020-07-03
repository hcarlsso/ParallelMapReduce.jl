using Test
using ParallelMapReduce
using Distributed

@testset "Pmapreduce" begin

    if nprocs() == 1
        addprocs(2)
    elseif nworkers() > 2
        error("Too many processes")
    end

    @everywhere using Pkg
    @everywhere pkg"activate ."
    @everywhere pkg"precompile"
    @everywhere using ParallelMapReduce
    function test()
        @everywhere function f(n)
            sleep(n)
            n
        end

        args = [5, ones(Int, 9)...]

        val_even, t_even  = @timed pmapreduce(f, +, args)
        val_red_local, t_red_local  = @timed pmapreduce(
            f, +, args; algorithm = :reduction_local
        )
        val_red_master, t_red_master  = @timed pmapreduce(
            f, +, args; algorithm = :reduction_master
        )

        @test val_even ==  val_red_master == val_red_local
        @test t_red_local < t_even
        @test t_red_master < t_even
    end

    test()

end
