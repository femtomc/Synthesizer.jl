module Synthesizer

using Jaynes
using IRTools
using IRTools: @dynamo, IR, recurse!
using MacroTools
using MacroTools: rmlines, unblock

# ------------ Fundamentals ------------ #

function _lang(name, expr::Expr)
    @capture(expr, ex_ = begin body__ end)
    trans = Any[]
    probs = Float64[]
    for subexpr in body
        @capture(subexpr, prob_ => sbod_)
        push!(probs, prob)
        nbod = MacroTools.postwalk(sbod) do k
            if k == ex
                Expr(:call, name)
            else
                k
            end
        end
        push!(trans, nbod)
    end
    trans = map(enumerate(trans)) do (i, t)
        i == length(trans) && return Expr(:return, t)
        t = MacroTools.postwalk(t) do sub
            if @capture(sub, $name(args__))
                quote rand($i, $name) end
            else
                sub
            end
        end
        quote if selection == $i
                return $t
            end
        end
    end
    
    return MacroTools.postwalk(unblock ∘ rmlines, quote
                                   function $name()
                                       selection = rand(:sel, Categorical($probs))
                                       $(trans...)
                                   end
                               end)
end

macro lang(name, expr)
    fn = _lang(name, expr)
    fn
end

# ------------ Example usage 1 ------------ #

# Declare a probabilistic DSL.
@lang (arithmetic) expr = begin
    0.2 => expr * expr
    0.3 => expr + expr
    0.4 => 2.0
    0.1 => 1.0
end

ret, cl = simulate(arithmetic)

# Insert a hole into a function.
hole(lang::Function) = rand(gensym(), lang)

function foo(x::Float64)
    y = x * hole(arithmetic)
    q = hole(arithmetic)
    return y * q
end

function synthesize(samples::Int, fn::Function, args::Tuple, d::Distribution; reject = -Inf)
    score = Float64[]
    calls = Jaynes.CallSite[]
    for i in 1 : samples
        ret, cl = simulate(fn, args...)
        if logpdf(d, ret) > reject
            push!(score, logpdf(d, ret))
            push!(calls, cl)
        end
    end
    return Jaynes.Particles(calls, score, 0.0)
end

# Score a bunch of samples from the grammar.
ps = synthesize(100, foo, (5.0, ), Normal(5.0, 1.0); reject = -10.0)
map(1:length(ps)) do i
    display(ps.calls[i].trace)
    println(ps.lws[i])
end

end # module
