include("utils.jl")

function task_sample()
    parent = current_task()
    task = @task begin
        ptr1 = sample_stackpointer()
        #=
        bt_data = ccall(
            :jl_backtrace_from_here,
            Ref{Base.SimpleVector},
            (Cint, Cint),
            true,
            0,
        )
        =#
        yieldto(parent, ptr1)
        # Suspend the task using `yieldto` to avoid the stack buffer to be GC'ed
    end
    return task, yieldto(task)
end

"""
    guess_task_layout(task, ptr1) -> offset_bytes

Return the guessed offset of the hidden field `stkbuf` of `jl_task_t` in bytes.

`ptr1` is a frame address of `task` "reasonably early" in the call stack.
"""
function guess_task_layout(task, ptr1)
    GC.@preserve task begin
        offset_base = (sizeof(Task) ÷ sizeof(UInt)) * sizeof(UInt)
        ptr0 = pointer_from_objref(task) + offset_base
        for offset in 0:64
            pstkbuf = Ptr{Ptr{Cvoid}}(ptr0 + sizeof(UInt) * offset)
            pbufsz = Ptr{Csize_t}(pstkbuf + sizeof(UInt))
            stkbuf = unsafe_load(pstkbuf)
            bufsz = unsafe_load(pbufsz)
            stkbase = stkbuf + bufsz
            if stkbase - ptr1 < 2000
                return offset_base + offset * sizeof(UInt)
            end
        end
    end
    return nothing
end

if !@isdefined(only)
    function only(xs)
        xs = collect(xs)
        @assert length(xs) == 1
        return xs[1]
    end
end

function guess_task_layout()
    samples = [task_sample() for _ in 1:100]
    guesses = [guess_task_layout(args...) for args in samples]
    return only(unique(guesses))
end

if realpath(PROGRAM_FILE) == realpath(@__FILE__)
    sample_stackpointer()
    println(guess_task_layout())
end
