# ParallelMapReduce.jl

This package provides the function `pmapreduce`. This function is essentially
```julia
function pmapreduce(f, op, itrs)
    @distributed op for arg in itrs
        f(arg)
    end
end
```
However, since `@distributed` partitions `itrs` evenly across nodes, some nodes
may be idle if the nodes are different in computational speed, or equivalently
if `f` takes different time to compute depending on the input. With the added option
`pmapreduce(f, op, itrs...; algorithm = :reduction_local)`, computations are
dynamically load balanced, that is, the elements in `itrs` are only distributed
to a worker which is free. The result of each computation of `f` is stored
and reduced locally, until `itrs` is exhausted, and then sent back to the master
process, where the results from the nodes are further reduced, thus saving
communication bandwidth.
```julia
addprocs(2)

function test()
    @everywhere function f(n)
        sleep(n)
        n
    end

    args = [5, ones(Int, 9)...]

    val_even = @time pmapreduce(f, +, args)
    val_uneven  = @time pmapreduce(f, +, args; algorithm = :reduction_local)

    println(val_even, " ", val_uneven)
end

julia> test()
  9.039506 seconds (150 allocations: 6.562 KiB)
  7.048571 seconds (1.91 k allocations: 81.703 KiB)
14 14
```
The option `:reduction_master` is also available, where the result of every
`f` computation is sent back to the master, where the reduction is performed.
