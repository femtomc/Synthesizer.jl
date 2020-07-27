module Sorting

include("../src/Synthesizer.jl")
using .Synthesizer

# ------------ Example usage 2 ------------ #

# A small array operation language.
swap!(x::Array) = begin
    if length(x) != 1
        x[1], x[end] = x[end], x[1]
    end
    return x
end

swap_tail!(x::Array) = begin
    if length(x) != 1
        x[end - 1], x[end] = x[end], x[end - 1]
    end
    return x
end

swap_head!(x::Array) = begin
    if length(x) != 1
        x[1], x[2] = x[2], x[1]
    end
    return x
end

reorder(x::Array) = begin
    new = typeof(x)()
    if length(x) != 1
        len = length(x)
        if len % 2 == 0
            fst = x[1 : Int(floor(len / 2))]
            snd = x[Int(ceil(len / 2)) + 1 : end]
            append!(snd, fst)
        else
            fst = x[1 : Int(floor(len / 2))]
            snd = x[Int(ceil(len / 2)) : end]
            append!(snd, fst)
        end
    end
    return snd
end

@lang (array_operation) _1 expr = begin
    0.20 => swap!(_1)
    0.20 => reorder(_1)
    0.20 => swap_head!(_1)
    0.20 => swap_tail!(_1)
    0.20 => reverse(_1)
end

# Some Boolean holes.
@lang (boolean) expr = begin
    0.7 => true
    0.3 => false
end

function check(x::Array{T}) where T <: Number
    length(x) == 1 && return true
    i = x[1]
    for j in x[2 : end]
        if !(i < j)
            return false
        end
        i = j
    end
    return true
end

function foo(x::Array{T}) where T <: Number
    while !check(x)
        x = hole(array_operation, x)
    end
    return x
end

init, target = reverse([i for i in 1 : 10]), [i for i in 1 : 10]
ret, cl = synthesize(foo, [(init, target)])
!(cl == nothing) && display(cl.trace)

end # module
