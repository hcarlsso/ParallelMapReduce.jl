# ParallelMapReduce.jl

This package provides the function `pmapreduce`. This function is essentially
```julia
function pmapreduce(f, op, itrs...)
    @distributed op for arg in collect(zip(itrs...))
        f(arg...)
    end
end
```
However, since `@distributed` partitions `itrs` evenly across nodes, some nodes
may be idle if they have different speeds, or equivalently `f` maybe take
different time depending on the input. Thus, with the added option of
`pmapreduce(f, +, itrs...; uneven = true)`, computations are distributed
across workers, when a worker is free. The results are reduced locally,
and then sent back to the master process, where the results from the nodes
are reduced.

```julia
addprocs(2)

function test()
    @everywhere function f(n)
        sleep(n)
        n
    end

    args = [5, ones(Int, 9)...]

    val_even = @time pmapreduce(f, +, args)
    val_uneven  = @time pmapreduce(f, +, args; uneven = true)

    println(val_even, " ", val_uneven)
end

julia> test()
  9.039506 seconds (150 allocations: 6.562 KiB)
  7.048571 seconds (1.91 k allocations: 81.703 KiB)
14 14
```
