module TestIntern

using ParallelIDMappings
using Test

function check_compare(f!, xs)
    ys = similar(xs)
    f!(ys, xs)
    @test ys == xs
    if f! === ParallelIDMappings.intern_serial! || Threads.nthreads() == 1
        @test map(pointer, unique(xs)) == unique(map(pointer, ys))
    else
        @test map(pointer, unique(ys)) == unique(map(pointer, ys))
    end
end

function test_compare()
    @testset for n in [10, 100, 1000, 10000],
        f! in [
            ParallelIDMappings.intern_serial!,
            ParallelIDMappings.intern_localcopies!,
            ParallelIDMappings.intern_concurrentdict!,
            ParallelIDMappings.intern_leftright!,
        ]

        strs = ParallelIDMappings.randomstrings(n)
        check_compare(f!, strs)
    end
end

end  # module
