using PosixChannels
using Test

@testset "PosixChannels.jl" begin
    writer = PosixChannel{Int}("test", mode=:w)
    reader = PosixChannel{Int}("test", mode=:r)

    @test writer.name == reader.name

    @test length(writer) == 0
    @test !isready(reader)

    put!(writer, 1)

    @test length(writer) == 1
    @test isready(reader)

    v = take!(reader)
    @test v == 1
    @test length(reader) == 0
    @test !isready(reader)

    close(reader)
    close(writer)

    unlink(writer)

end