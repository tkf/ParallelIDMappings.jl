module BenchIntern

using BenchmarkTools
using ParallelIDMappings

const CACHE = Ref{Any}()

function setup(; nitems = 2^20, ps = [1e-3, 1e-4, 1e-5], options...)
    probs = Iterators.map(ps) do p
        xs = ParallelIDMappings.randomstrings(nitems; p, nchars = 1000, options...)
        ys = similar(xs)
        p => (; ys, xs)
    end
    CACHE[] = Dict(probs)
    T = typeof(last(first(CACHE[])))

    suite = BenchmarkGroup()
    for p in ps
        s1 = suite["p=$p"] = BenchmarkGroup()
        for f! in [
            ParallelIDMappings.intern_serial!,
            ParallelIDMappings.intern_localcopies!,
            ParallelIDMappings.intern_concurrentdict!,
            ParallelIDMappings.intern_leftright!,
        ]
            name = string(f!)
            @assert startswith(name, "intern_")
            impl = name[length("intern_")+1:end-1]
            s1["impl=:$impl"] = @benchmarkable($f!(ys, xs), setup = begin
                prob = CACHE[][$p]::$T
                ys = prob.ys
                xs = prob.xs
            end)
        end
    end
    return suite
end

function clear()
    CACHE[] = nothing
end

end  # module
