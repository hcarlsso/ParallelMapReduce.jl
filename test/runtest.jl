using Test
using ParallelMapReduce
using Distributed

@testset "Pmapreduce" begin

    addprocs(2)
    @everywhere using Pkg
    @everywhere pkg"activate ."
    @everywhere pkg"precompile"
    @everywhere using ParallelMapReduce
    function test()
        @everywhere function f(n)
            sleep(n)
            n
        end

        args = [3, ones(Int, 9)...]

        val_even, t_even  = @timed pmapreduce(f, +, args)
        val_uneven, t_uneven  = @timed pmapreduce(f, +, args; uneven = true)

        @test val_even == val_uneven
        @test t_uneven < t_even
    end

    test()

    wait(rmprocs(workers()))

end
