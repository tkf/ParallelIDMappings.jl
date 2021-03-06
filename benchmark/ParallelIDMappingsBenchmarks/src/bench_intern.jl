module BenchIntern

using BenchmarkTools
using ParallelIDMappings

const CACHE = Ref{Any}()

function setup(;
    smoke = false,
    nitems = smoke ? 10 : 2^20,
    ps = smoke ? [0.1] : [1e-3, 1e-4, 1e-5],
    include_serial = true,
    fs = filter!(
        !isnothing,
        Any[
            include_serial ? ParallelIDMappings.intern_serial! : nothing,
            ParallelIDMappings.intern_localcopies!,
            ParallelIDMappings.intern_concurrentdict!,
            ParallelIDMappings.intern_leftright!,
        ],
    ),
    options...,
)
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
        for f! in fs
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
