module Sorting

include("../src/Synthesizer.jl")
using .Synthesizer

# ------------ Example usage 2 ------------ #

# Array operation primitives.
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

# A small array operation language.
@lang (array_operation) _1 expr = begin
    0.10 => swap!(_1)
    0.10 => reorder(_1)
    0.10 => swap_head!(_1)
    0.20 => swap_tail!(_1)
    0.50 => reverse(_1)
end

# Utility check to assert to assert the sorted property. NOT USED.
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

# Function with holes.
function sort!(x::Array{T}) where T <: Number
    x = hole(:hole, array_operation, x)
    return x
end

# Examples.
sc = [[i for i in 1 : j] for j in 1 : 20]
sc = map(sc) do s
    reverse(s), s
end

@time cls = synthesize(sort!, sc; iters = 1000)
!(cls == nothing) && begin
    map(cls) do cl
        display(cl.trace)
    end
end

end # module
