# SimpleSegmentedStacks: Manual segmented stack for Julia

Suppose you have an absurdly recursive function:

```julia
julia> @noinline function f(x)
           if x == 0
               return 0
           else
               return f(x - 1) + x
           end
       end;

julia> f(2^20)
ERROR: StackOverflowError:
```

You can use `SimpleSegmentedStacks.call` to avoid the stack overflow:

```julia
julia> using SimpleSegmentedStacks

julia> @noinline function g(x)
           if x == 0
               return 0
           else
               return SimpleSegmentedStacks.call() do
                   g(x - 1)
               end + x
           end
       end;

julia> g(2^20)
549756338176
```
