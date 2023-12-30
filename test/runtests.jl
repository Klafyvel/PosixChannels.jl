using PosixChannels
using Test
using Aqua
using JET

@testset "PosixChannels.jl" begin
    Aqua.test_all(PosixChannels)

    @test_call PosixChannel{Int}("jet", mode=:rw)
    jet = PosixChannel{Int}("jet", mode=:rw)
    @test_call length(jet)
    @test_call isnonblocking(jet)

    @test_call put!(jet, 1)
    @test_call take!(jet)
    @test_call isready(jet)
    @test_call wait(jet)

    @test_call close(jet)
    @test_call unlink(jet)

    @test_call PosixChannels.systemmsgdefault()
    @test_call PosixChannels.systemmsgmax()
    @test_call PosixChannels.systemmsgsizedefault()
    @test_call PosixChannels.systemmsgsizemax()
    @test_call PosixChannels.systemqueuesmax()

    @test_opt ignored_modules = (Base,) length(jet)
    @test_opt ignored_modules = (Base,) isnonblocking(jet)

    @test_opt ignored_modules = (Base,) put!(jet, 1)
    @test_opt ignored_modules = (Base,) take!(jet)
    @test_opt ignored_modules = (Base,) isready(jet)
    @test_opt ignored_modules = (Base,) wait(jet)

    @test_opt ignored_modules = (Base,) close(jet)
    @test_opt ignored_modules = (Base,) unlink(jet)

    close(jet)
    unlink(jet)

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
