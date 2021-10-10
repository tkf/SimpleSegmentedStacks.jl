function _guess_stkbuf_offset()
    script = joinpath(@__DIR__, "guess_task_layout.jl")
    cmd = `$(Base.julia_cmd()) $script`
    return parse(Int, read(pipeline(cmd; stderr = stderr), String))
end

include_dependency("guess_task_layout.jl")
const STKBUF_OFFSET = _guess_stkbuf_offset()
const BUFSZ_OFFSET = STKBUF_OFFSET + sizeof(UInt)

@inline function getstkbuf(task)
    GC.@preserve task begin
        ptr = pointer_from_objref(task) + STKBUF_OFFSET
        stkbuf = unsafe_load(Ptr{Ptr{Cvoid}}(ptr))
    end
    return stkbuf
end

@inline function getbufsz(task)
    GC.@preserve task begin
        ptr = pointer_from_objref(task) + BUFSZ_OFFSET
        bufsz = unsafe_load(Ptr{Csize_t}(ptr))
    end
    return bufsz
end

function verify_getbufsz()
    default = Int(getbufsz(Task(nothing)))
    @assert getbufsz(Task(nothing, 2 * default)) == 2 * default
    @assert getbufsz(Task(nothing, 4 * default)) == 4 * default
    @assert getbufsz(Task(nothing, 8 * default)) == 8 * default
end

verify_getbufsz()

# Ref: https://github.com/tkf/InferableTasks.jl/blob/master/src/InferableTasks.jl
const HAS_INVOKE_IN_WORLD = isdefined(Base, :invoke_in_world)

const LAST_PTR = Ref(UInt(0))

"""
    SimpleSegmentedStacks.call(f)

Call `f()`.  Allocate the new call stack if the current call stack already
consumed too much stack space.

Error thrown in `f` may be wrapped in `TaskFailedException`.
"""
function SimpleSegmentedStacks.call(f)
    task = current_task()
    stkbuf = getstkbuf(task)
    bufsz = getbufsz(task)
    ptr = sample_stackpointer()
    LAST_PTR[] = UInt(ptr)
    if (
        task === Base.roottask ||  # bufsz of root task is not accurate
        (stkbuf !== C_NULL && ptr > stkbuf && ptr - stkbuf < bufsz ÷ 32)
    )
        iserror = Ref(true)
        parent = current_task()
        world = @static if HAS_INVOKE_IN_WORLD
            ccall(:jl_get_tls_world_age, UInt, ())
        end
        task = @task try
            @static if HAS_INVOKE_IN_WORLD
                local y = Base.invoke_in_world(world, f)
            else
                local y = f()
            end
            iserror[] = false
            yieldto(parent, y)
        catch
            yieldto(parent, nothing)
            rethrow()
        end
        y = yieldto(task)
        if iserror[]
            yield(task)
            wait(task)::Union{}
        else
            @static if HAS_INVOKE_IN_WORLD
                return y::Core.Compiler.return_type(f, Tuple{})
            else
                return y
            end
        end
    else
        return f()
    end
end
