module TestPool

using ParallelIDMappings
using Test

function check_compare(strs)
    m_serial = ParallelIDMappings.pool_serial(strs)
    m_localcopies = ParallelIDMappings.pool_localcopies(strs)
    m_concurrentdict = ParallelIDMappings.pool_concurrentdict(strs)
    m_leftright = ParallelIDMappings.pool_leftright(strs)
    @test m_localcopies == m_serial
    @test m_concurrentdict == m_serial
    @test m_leftright == m_serial
end

function test_compare()
    @testset for n in [10, 100, 1000, 10000]
        strs = ParallelIDMappings.randomstrings(n)
        check_compare(strs)
    end
end

end  # module
