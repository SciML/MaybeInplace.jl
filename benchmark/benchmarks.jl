using MaybeInplace, BenchmarkTools
using StableRNGs

const SUITE = BenchmarkGroup()
const rng = StableRNG(123)

N = 500
A = rand(rng, N, N)
y = rand(rng, N)
x = rand(rng, N)
yy = copy(y)

# =============================================================================
# @bb in-place operations (MaybeInplace's core macro)
# =============================================================================

SUITE["bb"] = BenchmarkGroup()

# broadcasted axpy: y .= y .+ a .* x
function bb_axpy!(y, x, a)
    @bb y .+= a .* x
    return y
end
SUITE["bb"]["axpy"] = @benchmarkable bb_axpy!($yy, $x, 2.0)

# matvec: y .= A * x
function bb_matvec(y, A, x)
    @bb y .= A * x
    return y
end
SUITE["bb"]["matvec"] = @benchmarkable bb_matvec($yy, $A, $x)

# @. broadcasted assignment
function bb_elementwise(y, x)
    @bb @. y = y * x
    return y
end
SUITE["bb"]["elementwise"] = @benchmarkable bb_elementwise($yy, $x)

# =============================================================================
# Baseline comparisons (same work without the macro)
# =============================================================================

SUITE["baseline"] = BenchmarkGroup()
SUITE["baseline"]["axpy"] = @benchmarkable $yy .+= 2.0 .* $x
SUITE["baseline"]["matvec"] = @benchmarkable $yy .= $A * $x
