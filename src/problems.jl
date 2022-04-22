ParallelIDMappings.randomstrings(nitems; options...) =
    ParallelIDMappings.randomstrings(GLOBAL_RNG, nitems; options...)

function ParallelIDMappings.randomstrings(
    rng,
    nitems;
    p = nothing,
    nuniques = nothing,
    nchars = 50,
)
    if (p !== nothing) && (nuniques !== nothing)
        error("options `p` and `nuniques` are mutually exclusive")
    end
    if nuniques === nothing
        if p === nothing
            nuniques = max(2, ceil(Int, nitems * 0.01))
        else
            nuniques = ceil(Int, nitems * p)
        end
    end
    strs = [randstring(rng, nchars) for _ in 1:nuniques]
    return map(s -> sprint(print, s), rand(rng, strs, nitems))
end
