function ParallelIDMappings.intern_serial!(ys, xs, ::Type{D} = Dict) where {D}
    dict = D{eltype(xs),eltype(xs)}()
    for i in eachindex(ys, xs)
        x = xs[i]
        ys[i] = get!(dict, x, x)
    end
    return ys
end

function ParallelIDMappings.intern_localcopies!(ys, xs; options...)
    zs = ParallelIDMappings.pool_localcopies(xs; options...)
    Threads.@threads for i in eachindex(zs)
        ys[i] = zs[i]
    end
    return ys
end

function ParallelIDMappings.intern_concurrentdict!(ys, xs)
    dict = ConcurrentDict{eltype(xs),eltype(xs)}()
    Threads.@threads for i in eachindex(ys, xs)
        x = xs[i]
        ys[i] = get!(dict, x, x)
    end
    return ys
end

struct _NotSet end
const NOTSET = _NotSet()

function ParallelIDMappings.intern_leftright!(ys, xs, ::Type{D} = Dict) where {D}
    guard = LeftRight.Guard() do
        D{eltype(xs),eltype(xs)}()
    end
    Threads.@threads for i in eachindex(ys, xs)
        x = xs[i]
        y = guarding_read(guard) do dict
            get(dict, x, NOTSET)
        end
        ys[i] = if y === NOTSET
            guarding(guard) do dict
                get!(dict, x, x)
            end
        else
            y
        end
    end
    return ys
end
