# MaybeInplace.jl

MaybeInplace.jl provides macros for writing array code that uses mutating
operations when the target supports mutation and out-of-place operations when it
does not.

```@contents
Pages = ["api.md"]
Depth = 2
```

## Example

```julia
using MaybeInplace

function add_arrays!(result, a, b)
    @bb result .= a .+ b
    return result
end

add_arrays!([0.0, 0.0], [1.0, 2.0], [3.0, 4.0])
```

See the [API](@ref) page for the documented public interface.
