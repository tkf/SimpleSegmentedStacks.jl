# https://github.com/JuliaLang/julia/pull/42585#discussion_r727423060
sample_stackpointer() = ccall("llvm.frameaddress", llvmcall, Ptr{Cvoid}, (Int,), 0)
