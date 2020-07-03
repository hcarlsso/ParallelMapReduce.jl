module ParallelMapReduce

using Distributed

export pmapreduce

"""
    pmapreduce(f, op, [::AbstractWorkerPool], c...; algorithm = :even)

A parallel version of the function `mapreduce` using available workers, where
`f` is applied to each element in `c`, and the result is reduced using
`op`.

There are three choices for `algorithm`:
- `:even`, evenly partitions the elements in `c` across workers, see `@distributed`.
- `:reduction_local`, the elements in `c` are asynchronously distributed to the workers. Each element is sent to the next available worker. The result of `f` is reduced and stored locally. When `c` is exhausted, the local results are sent back to the master, who makes the final reduction.
- `:reduction_master`, similar to `:reduction_local`, but the result of each computation of `f` is sent back to the master, where all reductions are made.
"""
function pmapreduce(f, op, p::AbstractWorkerPool, c; algorithm = :even)
    options = Dict(
        :even => (f, op, p, c) -> pmapreduce_even(f, op, c),
        :reduction_local => (f, op, p, c) -> pmapreduce_uneven(f, op, p, c),
        :reduction_master => (f, op, p, c) -> pmapreduce_master_reduction(f, op, p, c)
    )
    if algorithm in keys(options)
        return options[algorithm](f, op, p, c)
    else
        error("Unsupported option $(algorithm)")
    end
end

pmapreduce(f, op, p::AbstractWorkerPool, c1, c...; kwargs...) = pmapreduce(
    a->f(a...), op, p, zip(c1, c...); kwargs...
)
pmapreduce(f, op, c; kwargs...) = pmapreduce(
    f, op, default_worker_pool(), c; kwargs...
)
pmapreduce(f, op, c1, c...; kwargs...) = pmapreduce(
    a->f(a...), op, zip(c1, c...); kwargs...
)

function pmapreduce_even(f, op, c)
    @distributed op for arg in c
        f(arg)
    end
end

function pmapreduce_uneven(f, op, p::AbstractWorkerPool, c)

    jobs = RemoteChannel(()-> Channel(length(p)))
    res = RemoteChannel(()-> Channel(length(p)))

    for pid in p.workers
        remote_do(_do_work_pmapreduce_uneven, pid, f, op, jobs, res)
    end

    # Make jobs
    for arg in c
        put!(jobs, arg)
    end
    close(jobs)

    # Collect results
    v = take!(res)
    if length(p) > 1
        for n in 2:length(p)
            v = op(v, take!(res))
        end
    end
    close(res)
    return v
end

function _do_work_pmapreduce_uneven(f, op, jobs, res)
    args = try
        take!(jobs)
    catch InvalidStateException
        # No work to do
        return nothing
    end

    v = f(args)

    while true
        args = try
            take!(jobs)
        catch InvalidStateException
            # We are done
            break
        end
        v = op(v, f(args))
    end
    put!(res, v)
    return nothing
end
"""
    Collect results from nodes and reduce on master.
"""
function pmapreduce_master_reduction(f, op, p::AbstractWorkerPool, c)

    iter = Base.AsyncGenerator(
        y -> remotecall_fetch(f, p, y), c; ntasks = length(p)
    )
    return reduce(op, iter)
end

end # module
