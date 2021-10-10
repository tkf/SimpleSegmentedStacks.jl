using SimpleSegmentedStacks
using Test

function wastestack(call, n)
    if n == 0
        return n
    end
    return call() do
        wastestack(call, n - 1)
    end + n
end

@noinline naivecall(f) = f()

function wastestack_in_task(call, n)
    task = @task wastestack(call, n)
    yield(task)
    try
        return fetch(task)
    catch err
        if @isdefined TaskFailedException
            @assert err isa TaskFailedException
        end
        return task.result
    end
end

@testset begin
    @test wastestack_in_task(SimpleSegmentedStacks.call, 2^18) isa Int
    @test wastestack(SimpleSegmentedStacks.call, 2^18) isa Int
    @test wastestack_in_task(naivecall, 2^18) isa StackOverflowError
end
