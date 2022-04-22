baremodule ParallelIDMappings

function pool_serial end
function pool_localcopies end
function pool_concurrentdict end
function pool_leftright end

# Problem generators
function randomstrings end

module Internal

using ..ParallelIDMappings: ParallelIDMappings

using ConcurrentCollections: ConcurrentCollections, ConcurrentDict
using LeftRight
using Random: GLOBAL_RNG, rand, randstring
using SplittablesBase: halve

include("pool.jl")
include("problems.jl")

end  # module Internal

end  # baremodule ParallelIDMappings
