using SafeTestsets

@safetestset "Code quality (Aqua.jl)" begin
    using Aqua, MaybeInplace
    Aqua.test_all(MaybeInplace; ambiguities = false)
end

@safetestset "Code linting (JET.jl)" begin
    using JET, MaybeInplace
    JET.test_package(MaybeInplace; target_defined_modules = true)
end
