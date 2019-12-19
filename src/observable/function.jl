export FunctionObservable, on_subscribe!
export FunctionObservableActorWrapper, on_next!, on_error!, on_complete!
export FunctionObservableSubscription, as_teardown, on_unsubscribe!
export make

"""
    FunctionObservable{D}

FunctionObservable wraps a callback `f` which is called when the Observable is initially subscribed to.
This function is given an Actor, to which new values can be nexted (with `next!(actor, data)`),
or an `error!`` method can be called to raise an error, or `complete!` can be called to notify of a successful completion.

# Arguments
- `f`: function to be invoked on subscription

See also: [`Subscribable`](@ref), [`make`](@ref)
"""
struct FunctionObservable{D} <: Subscribable{D}
    f :: Function
end

function on_subscribe!(observable::FunctionObservable{D}, actor::A) where { A <: AbstractActor{D} } where D
    wrapper = FunctionObservableActorWrapper{D, A}(false, actor)
    subscription = FunctionObservableSubscription{D, A}(wrapper)
    observable.f(wrapper)
    return subscription
end

mutable struct FunctionObservableActorWrapper{D, A <: AbstractActor{D} } <: Actor{D}
    is_unsubscribed :: Bool
    actor           :: A
end

function on_next!(actor::FunctionObservableActorWrapper{D, A}, data::D) where A <: AbstractActor{D} where D
    if !actor.is_unsubscribed
        next!(actor.actor, data)
    end
end

function on_error!(actor::FunctionObservableActorWrapper, err)
    if !actor.is_unsubscribed
        error!(actor.actor, err)
    end
end

function on_complete!(actor::FunctionObservableActorWrapper)
    if !actor.is_unsubscribed
        complete!(actor.actor)
    end
end

struct FunctionObservableSubscription{ D, A <: AbstractActor{D} } <: Teardown
    wrapper :: FunctionObservableActorWrapper{D, A}
end

as_teardown(::Type{<:FunctionObservableSubscription}) = UnsubscribableTeardownLogic()

function on_unsubscribe!(subscription::FunctionObservableSubscription)
    subscription.wrapper.is_unsubscribed = true
    return nothing
end

"""
    make(f::Function, type::Type{D})

Creates a FunctionObservable.

# Arguments
- `f`: function to be invoked on subscription
- `type`: type of data in observable

# Examples
```jldoctest
using Rx

source = make(Int) do actor
    next!(actor, 0)
    complete!(actor)
end

subscription = subscribe!(source, LoggerActor{Int}());
unsubscribe!(subscription)
;

# output

[LogActor] Data: 0
[LogActor] Completed

```

```jldoctest
using Rx

source = make(Int) do actor
    next!(actor, 0)
    setTimeout(100) do
        next!(actor, 1)
        complete!(actor)
    end
end

subscription = subscribe!(source, LoggerActor{Int}())
unsubscribe!(subscription)
;

# output

[LogActor] Data: 0

```
"""
make(f::Function, type::Type{D}) where D = FunctionObservable{D}(f)