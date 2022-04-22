module BenchPool

using BenchmarkTools
using ParallelIDMappings

const CACHE = Ref{Any}()

function setup(; nitems = 2^22, ps = [1e-4, 1e-5, 1e-6], options...)
    CACHE[] = Dict(
        p => ParallelIDMappings.randomstrings(nitems; p, nchars = 1000, options...) for
        p in ps
    )
    T = typeof(last(first(CACHE[])))

    suite = BenchmarkGroup()
    for p in ps
        s1 = suite["p=$p"] = BenchmarkGroup()
        for f in [
            ParallelIDMappings.pool_serial,
            ParallelIDMappings.pool_localcopies,
            ParallelIDMappings.pool_concurrentdict,
            ParallelIDMappings.pool_leftright,
        ]
            name = string(f)
            @assert startswith(name, "pool_")
            impl = name[length("pool_")+1:end]
            s1["impl=:$impl"] = @benchmarkable $f(x) setup = (x = CACHE[][$p]::$T)
        end
    end
    return suite
end

function clear()
    CACHE[] = nothing
end

end  # module
