# MaybeInplace

[![Join the chat at https://julialang.zulipchat.com #sciml-bridged](https://img.shields.io/static/v1?label=Zulip&message=chat&color=9558b2&labelColor=389826)](https://julialang.zulipchat.com/#narrow/stream/279055-sciml-bridged)

[![CI](https://github.com/SciML/MaybeInplace.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/SciML/MaybeInplace.jl/actions/workflows/CI.yml)
[![codecov](https://codecov.io/gh/SciML/MaybeInplace.jl/branch/main/graph/badge.svg?)](https://codecov.io/gh/SciML/MaybeInplace.jl)
[![Package Downloads](https://shields.io/endpoint?url=https://pkgs.genieframework.com/api/v1/badge/MaybeInplace)](https://pkgs.genieframework.com?packages=MaybeInplace)
[![Aqua QA](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)

[![ColPrac: Contributor's Guide on Collaborative Practices for Community Packages](https://img.shields.io/badge/ColPrac-Contributor%27s%20Guide-blueviolet)](https://github.com/SciML/ColPrac)
[![SciML Code Style](https://img.shields.io/static/v1?label=code%20style&message=SciML&color=9558b2&labelColor=389826)](https://github.com/SciML/SciMLStyle)

MaybeInplace.jl solves a common problem in Julia: code written for mutable arrays often fails when used with immutable arrays (like StaticArrays). This package provides macros (`@bb`, `@bangbang`, or `@❗`) that automatically rewrite operations to work with both mutable and immutable arrays, choosing in-place operations when possible and out-of-place operations when necessary.

## Installation

<p>
MaybeInplace is a &nbsp;
    <a href="https://julialang.org">
        <img src="https://raw.githubusercontent.com/JuliaLang/julia-logo-graphics/master/images/julia.ico" width="16em">
        Julia Language
    </a>
    &nbsp; package. To install MaybeInplace,
    please <a href="https://docs.julialang.org/en/v1/manual/getting-started/">open
    Julia's interactive session (known as REPL)</a> and press <kbd>]</kbd> key in the REPL to use the package mode, then type the following command
</p>

```julia
pkg> add MaybeInplace
```

## Quick Example

```julia
using MaybeInplace, StaticArrays

# Without @bb: This function only works with mutable arrays
function add_arrays!(result, a, b)
    result .= a .+ b
    return result
end

# Works with regular arrays
add_arrays!([0.0, 0.0], [1.0, 2.0], [3.0, 4.0])  # ✓ Works

# Fails with StaticArrays (immutable)
# add_arrays!(@SVector[0.0, 0.0], @SVector[1.0, 2.0], @SVector[3.0, 4.0])  # ✗ Error!

# With @bb: This function works with both mutable and immutable arrays
function add_arrays_generic!(result, a, b)
    @bb result .= a .+ b
    return result
end

# Works with regular arrays (uses in-place operation)
add_arrays_generic!([0.0, 0.0], [1.0, 2.0], [3.0, 4.0])  # ✓ Returns [4.0, 6.0]

# Also works with StaticArrays (uses out-of-place operation)
add_arrays_generic!(@SVector[0.0, 0.0], @SVector[1.0, 2.0], @SVector[3.0, 4.0])  # ✓ Returns @SVector[4.0, 6.0]
```

## How It Works

The `@bb` macro inspects the array at runtime and chooses the appropriate operation. For example:

```julia
@bb @. x = y + z
```

becomes:

```julia
if setindex_trait(x) === CanSetindex()
    @. x = y + z  # In-place for mutable arrays
else
    x = @. y + z  # Out-of-place for immutable arrays
end
```

## Supported Operations

The macro supports the following operations:

1. `copyto!(y, x)` - Copy operations
2. `x .= <expr>` - Broadcasting assignment
3. `@. <expr>` - Broadcast macro
4. `x .+= <expr>`, `x .-= <expr>`, `x .*= <expr>`, `x ./= <expr>` - Compound assignment operators
5. `x = copy(y)` - Copy with assignment
6. `x = similar(y)` - Similar array creation
7. `x = zero(y)` - Zero initialization
8. `axpy!(a, x, y)` - BLAS-style operations
9. `x = y × z` - Custom matrix multiplication operator (typed with `\times<tab>`)

For a complete list and detailed examples, see the docstring: `?@bb`
