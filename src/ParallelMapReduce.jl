module ParallelMapReduce

using Distributed

export pmapreduce

"""
    pmapreduce(f, op, itrs...; uneven = false)

A parallel version of the function `mapreduce` using all available workers, where
`f` is executed on all available workers, and the result is locally reduced using
`op`. Finally, the reduced results on the workers are sent to the master node and
further reduced.

By default, `uneven=false`, meaning `itrs` are evenly partitioned across workers,
see `@distirbuted`. When specifying `uneven=true`, each element in `itrs` is sent
to the next available worker, see `pmap`. Unlike `pmap`, the result is reduced
locally, and then sent back to the master process.

"""
function pmapreduce(f, op, itrs...; uneven = false)
    if uneven
        return pmapreduce_uneven(f, op, itrs...)
    else
        return pmapreduce_even(f, op, itrs...)
    end
end

function pmapreduce_even(f, op, itrs...)
    @distributed op for arg in collect(zip(itrs...))
        f(arg...)
    end
end

function pmapreduce_uneven(f, op, itrs...)
    itr = collect(zip(itrs...))

    all_w = workers()[1:min(nworkers(), length(itr))]
    jobs = RemoteChannel(()-> Channel(length(all_w)))
    res = RemoteChannel(()-> Channel(length(all_w)))

    for pid in all_w
        remotecall(_do_work_pmapreduce_uneven, pid, f, op, jobs, res)
    end

    # Make jobs
    for job_arg in itr
        put!(jobs, job_arg)
    end
    close(jobs)

    # Collect results
    v = take!(res)
    if length(all_w) > 1
        for n in 2:length(all_w)
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

    v = f(args...)

    while true
        args = try
            take!(jobs)
        catch InvalidStateException
            # We are done
            break
        end
        v = op(v, f(args...))
    end
    put!(res, v)
    return nothing
end


end # module
