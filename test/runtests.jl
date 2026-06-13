using SafeTestsets, Test
using SciMLTesting

run_tests(;
    core = joinpath(@__DIR__, "basictests.jl"),
    groups = Dict(
        "QA" => (; env = joinpath(@__DIR__, "qa"), body = () -> begin
            include(joinpath(@__DIR__, "qa", "qa.jl"))
        end),
    ),
)
