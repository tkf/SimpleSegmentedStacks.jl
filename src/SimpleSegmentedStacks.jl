baremodule SimpleSegmentedStacks

function call end

module Internal

using ..SimpleSegmentedStacks: SimpleSegmentedStacks

include("utils.jl")
include("internal.jl")

end  # module Internal

end  # baremodule SimpleSegmentedStacks
