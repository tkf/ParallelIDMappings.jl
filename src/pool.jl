struct GenericIDMappings{Refs,Pool,InvPool}
    refs::Refs
    pool::Pool
    invpool::InvPool
end

# const IDMappings{Eltype} = GenericIDMappings{Vector{Int},Vector{Eltype},Dict{Eltype,Int}}

function ParallelIDMappings.pool_serial(xs, ::Type{D} = Dict) where {D}
    refs = Vector{Int}(undef, length(xs))
    pool = eltype(xs)[]
    invpool = D{eltype(xs),Int}()
    nextid = 1
    for (i, x) in enumerate(xs)
        id = get!(invpool, x, nextid)
        if id == nextid
            nextid += 1
            push!(pool, x)
        end
        refs[i] = id
    end
    return GenericIDMappings(refs, pool, invpool)
end

function combine!(a, b)
    nextid = length(a.pool) + 1
    bmap = Vector{Int}(undef, length(b.pool))
    for (bid, x) in enumerate(b.pool)
        id = get!(a.invpool, x, nextid)
        if id == nextid
            nextid += 1
            push!(a.pool, x)
        end
        bmap[bid] = id
    end

    arefs = a.refs
    brefs = b.refs
    ia = lastindex(arefs)
    resize!(arefs, length(arefs) + length(brefs))
    for ib in eachindex(brefs)
        ia += 1
        @inbounds arefs[ia] = bmap[brefs[ib]]
    end

    return a
end

function pool_localcopies_dac(xs, basesize)
    if length(xs) <= basesize
        return ParallelIDMappings.pool_serial(xs)
    else
        left, right = halve(xs)
        task = Threads.@spawn pool_localcopies_dac(right, basesize)
        a = pool_localcopies_dac(left, basesize)
        b = fetch(task)::typeof(a)
        return combine!(a, b)
    end
end

ParallelIDMappings.pool_localcopies(xs; basesize = cld(length(xs), Threads.nthreads())) =
    pool_localcopies_dac(xs, basesize)

function pool_concurrentdict_process_chunk!(refs, xs, nextid, invpool)
    localid = Ref(0)
    i = firstindex(refs)
    for i in eachindex(refs, xs)
        localid[] = 0
        id = get!(invpool, xs[i]) do
            local id = localid[]
            if id == 0
                id = localid[] = Threads.atomic_add!(nextid, 1)
            end
            return id
        end
        refs[i] = id
        i += 1
    end
end

function pool_concurrentdict_process_dac!(refs, xs, nextid, invpool, basesize)
    if length(xs) <= basesize
        pool_concurrentdict_process_chunk!(refs, xs, nextid, invpool)
    else
        xs_left, xs_right = halve(xs)
        refs_left, refs_right = halve(refs)
        @assert length(xs_left) == length(refs_left)
        task = Threads.@spawn begin
            pool_concurrentdict_process_dac!(refs_right, xs_right, nextid, invpool, basesize)
        end
        pool_concurrentdict_process_dac!(refs_left, xs_left, nextid, invpool, basesize)
        wait(task)
    end
end

function ParallelIDMappings.pool_concurrentdict(
    xs;
    basesize = cld(length(xs), Threads.nthreads()),
)
    nextid = Threads.Atomic{Int}(1)
    invpool = ConcurrentDict{eltype(xs),Int}()
    refs = Vector{Int}(undef, length(xs))
    pool_concurrentdict_process_dac!(refs, xs, nextid, invpool, basesize)
    pool = Vector{eltype(xs)}(undef, nextid[] - 1)
    for (x, i) in invpool
        pool[i] = x
    end
    return GenericIDMappings(refs, pool, invpool)
end

function pool_leftright_process_chunk!(refs, xs, chunk, guard)
    for i in chunk
        x = xs[i]
        id = guarding_read(guard) do shared
            get(shared.invpool, x, 0)
        end
        if id == 0
            id = guarding(guard) do shared
                local nextid = shared.nextid[]
                local id = get!(shared.invpool, x, nextid)
                if id == nextid
                    shared.nextid[] = nextid + 1
                    push!(shared.pool, x)
                end
                return id
            end
        end
        refs[i] = id
    end
end

function ParallelIDMappings.pool_leftright(
    xs;
    basesize = cld(length(xs), Threads.nthreads()),
)
    guard = LeftRight.Guard() do
        (nextid = Ref(1), invpool = Dict{eltype(xs),Int}(), pool = eltype(xs)[])
    end
    refs = Vector{Int}(undef, length(xs))
    @sync for chunk in Iterators.partition(eachindex(xs, refs), basesize)
        Threads.@spawn pool_leftright_process_chunk!(refs, xs, chunk, guard)
    end
    (; invpool, pool) = guarding_read(identity, guard)
    return GenericIDMappings(refs, pool, invpool)
end

###
### Some useful APIs for GenericIDMappings
###

Base.@propagate_inbounds Base.getindex(a::GenericIDMappings, i) = a.pool[a.refs[i]]

function Base.:(==)(a::GenericIDMappings, b::GenericIDMappings)
    axes(a.refs) == axes(b.refs) || return false
    ok = isequal(a.refs, b.refs) && isequal(a.pool, b.pool)
    ok && return true

    for i in eachindex(a.refs, b.refs)
        x = @inbounds a[i]
        y = @inbounds b[i]
        isequal(x, y) || return false
    end
    return true
end
