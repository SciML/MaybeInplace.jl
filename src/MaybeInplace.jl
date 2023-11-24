module MaybeInplace

using LinearAlgebra, MacroTools
import ArrayInterface: can_setindex, restructure

## Documentation
__bangbang__docs = """
    @bangbang <expr>
    @bb <expr>
    @❗ <expr> # ❗ can be typed with \\:exclamation:<tab>

The `@bangbang` macro rewrites expressions to use out-of-place operations if needed. The
following operations are supported:

    1. `copyto!(y, x)`
    2. `x .(+/-/*)= <expr>`
    3. `x ./= <expr>`
    4. `copy(x)`
    5. `x .= <expr>`
    6. `@. <expr>`

This macro also allows some custom operators:

    1. `×` (typed with `\\times<tab>`): This is effectively a matmul operator. It is
       rewritten to use `mul!` if `y` can be setindex-ed else it is rewritten to use
       `restructure` to create a new array. If there is a `vec` on the rhs, `vec` is also
       applied to the lhs. This is useful for handling arbitrary dimensional arrays by
       flattening them.

!!! warning

    Using this on any operation not in the list will throw an error.

## Example

```julia
using MaybeInplace, StaticArrays

function my_non_generic_iip_oop(y, x)
    copyto!(y, x)
    return y
end

my_non_generic_iip_oop([0.0, 0.0], [1.0, 1.0]) # Works
my_non_generic_iip_oop(@SVector[0.0, 0.0], @SVector[1.0, 1.0]) # Fails
```

Typically this will fail if `y` cannot be setindex-ed. However, this macro will rewrite
the expression to use `copyto!` if the array supports `setindex!` (via ArrayInterface.jl)
else it will use `y = x`.

```
function my_generic_iip_oop(y, x)
    @bb copyto!(y, x)
    return y
end

my_generic_iip_oop([0.0, 0.0], [1.0, 1.0]) # Works
my_generic_iip_oop(@SVector[0.0, 0.0], @SVector[1.0, 1.0]) # Also Works
```

Importantly note that this doesn't respect the semantics of `copyto!`, rather it respects
only if the array is mutable, else it just assigns it to the variable. This is true for
all operations on the list.

!!! tip

    For extensive use of this Package, see the source code for NonlinearSolve.jl and
    SimpleNonlinearSolve.jl

!!! warning

    The generated code heavily relies on the julia compiler constant propating and
    eliminating branches. Using with tools like `Zygote.jl` might lead to slowdowns.
    In those cases, one should anyways use non-mutating code.
"""

## Main Function
function __bangbang__(M, expr; depth::Int = 1)
    new_expr = nothing
    if @capture(expr, a_Symbol = copy(b_))
        new_expr = :($(a) = $(__copy)($(setindex_trait)($(b)), $(b)))
    elseif @capture(expr, f_(a_Symbol, args__))
        g = get(OP_MAPPING, f, nothing)
        if g !== nothing
            new_expr = :($(a) = $(g)($(setindex_trait)($(a)), $(a), $(args...)))
        end
    elseif @capture(expr, a_=f_Symbol(b_, args__))
        g = get(OP_MAPPING, f, nothing)
        if g !== nothing
            new_expr = :($(a) = $(g)($(setindex_trait)($(a)), $(a), $(b), $(args...)))
        elseif f == :×
            new_expr = __handle_custom_operator(Val{:×}(), M, expr, depth)
        end
    elseif @capture(expr, @. a_ = f_)
        new_expr = __handle_dot_macro(M, a, f, depth)
    elseif expr.head == :macrocall
        new_expr = __bangbang__(M, Base.macroexpand(M, expr; recursive = true);
            depth = depth + 1)
    else
        new_expr = __handle_dot_op_equals_operators(M, expr, depth)
    end
    # If we have updated the expression return it, else throw an error
    if new_expr !== nothing
        depth == 1 && return esc(new_expr)
        return new_expr
    end
    return error("`$(expr)` cannot be handled. Check the documentation for allowed expressions.")
end

## Custom Operators
function __handle_custom_operator(::Val{:×}, M, expr, depth)
    @capture(expr, a_=×(b_, c_)) || error("Expected `a = b × c` got `$(expr)`")
    @capture(expr, a_=×(vec(b_), vec(c_))) && return nothing
    a_sym = gensym("a")
    if @capture(expr, a_=×(vec(b_), c_))
        return quote
            if $(setindex_trait)($(a)) === $(CanSetindex())
                $(a_sym) = $(_vec)($a)
                $(mul!)($(a_sym), $(_vec)($b), $(c))
                $(a) = $(_restructure)($(a), $(a_sym))
            else
                $(a) = $(_restructure)($a, $(_vec)($b) * $(c))
            end
        end
    elseif @capture(expr, a_=×(b_, vec(c_)))
        return quote
            if $(setindex_trait)($(a)) === $(CanSetindex())
                $(a_sym) = $(_vec)($a)
                $(mul!)($(a_sym), $(b), $(_vec)($c))
                $(a) = $(_restructure)($(a), $(a_sym))
            else
                $(a) = $(_restructure)($a, $(b) * $(_vec)($c))
            end
        end
    elseif @capture(expr, a_=×(b_, c_))
        return quote
            if $(setindex_trait)($(a)) === $(CanSetindex())
                $(mul!)($(a), $(b), $(c))
            else
                $(a) = $(_restructure)($a, $(b) * ($c))
            end
        end
    end
    return nothing
end

function __handle_dot_op_equals_operators(M, expr, depth)
    op = nothing
    al, bl = nothing, nothing
    @capture(expr, a_.=b_) && (op = __ignore_first; al = a; bl = b)
    @capture(expr, a_.+=b_) && (op = :.+; al = a; bl = b)
    @capture(expr, a_.-=b_) && (op = :.-; al = a; bl = b)
    @capture(expr, a_.*=b_) && (op = :.*; al = a; bl = b)
    @capture(expr, a_./=b_) && (op = :./; al = a; bl = b)
    if op !== nothing
        return quote
            if $(setindex_trait)($(al)) === $(CanSetindex())
                @. $(expr)
            else
                $(al) = $(op)($(al), $(bl))
            end
        end
    end
    return nothing
end

function __handle_dot_macro(M, a, f, depth)
    return quote
        if $(setindex_trait)($(a)) === $(CanSetindex())
            @. $(a) = $(f)
        else
            $(a) = @. $(f)
        end
    end
end

## Traits
abstract type AbstractMaybeSetindex end
struct CannotSetindex <: AbstractMaybeSetindex end
struct CanSetindex <: AbstractMaybeSetindex end

setindex_trait(::Number) = CannotSetindex()
setindex_trait(::Array) = CanSetindex()
# In recent versions of Julia, this function has a type stable return type even without
# overloading for sutom array types
setindex_trait(A) = ifelse(can_setindex(A), CanSetindex(), CannotSetindex())

## Operations
@inline __copyto!!(::CannotSetindex, x, y) = y
@inline __copyto!!(::CanSetindex, x, y) = (copyto!(x, y); x)

@inline __broadcast!!(::CannotSetindex, op, x, args...) = broadcast(op, args...)
@inline __broadcast!!(::CanSetindex, op, x, args...) = (broadcast!(op, x, args...); x)

@inline __sub!!(S, x, args...) = __broadcast!!(S, -, x, x, args...)
@inline __add!!(S, x, args...) = __broadcast!!(S, +, x, x, args...)
@inline __mul!!(S, x, args...) = __broadcast!!(S, *, x, x, args...)
@inline __div!!(S, x, args...) = __broadcast!!(S, /, x, x, args...)

@inline __copy(::CannotSetindex, x) = x
@inline __copy(::CanSetindex, x) = copy(x)

@inline __ignore_first(_, y) = y

const OP_MAPPING = Dict{Symbol, Function}(:copyto! => __copyto!!,
    :.-= => __sub!!, :.+= => __add!!, :.*= => __mul!!, :./= => __div!!,
    :copy => __copy)

## Macros
@doc __bangbang__docs
macro bangbang(expr)
    return __bangbang__(__module__, expr)
end

@doc __bangbang__docs
macro bb(expr)
    return __bangbang__(__module__, expr)
end

@doc __bangbang__docs
macro ❗(expr)
    return __bangbang__(__module__, expr)
end

@inline _vec(v) = v
@inline _vec(v::Number) = v
@inline _vec(v::AbstractArray) = vec(v)

@inline _restructure(y::Number, x::Number) = x
@inline _restructure(y, x) = restructure(y, x)

## Exports
export @bb, @bangbang, @❗

end
