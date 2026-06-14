using MaybeInplace

function copyto!!(y, x)
    @bb copyto!(y, x)
    return y
end

function eqop!!(y, x1, x2, x3, x4, x5)
    @bb y .= x1
    @bb y .+= x2
    @bb y .*= x3
    @bb y .-= x4
    @bb y ./= x5
    return y
end

function dotmacro!!(y, x, z)
    @bb @. y = x * z
    return y
end

function matmul!!(y, x, z)
    @bb y = x × z
    return y
end

function get_similar(x)
    @bb z = similar(x)
    return z
end
