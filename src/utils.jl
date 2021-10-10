if VERSION < v"1.6"
    @inline function sample_stackpointer()
        int = Base.llvmcall(
            """
            %aptr = alloca i64, i64 16
            %aint = ptrtoint i64* %aptr to i64
            ret i64 %aint
            """,
            Int64,
            Tuple{},
        )
        return Ptr{Cvoid}(int)
    end
else
    @inline function sample_stackpointer()
        int = Base.llvmcall((
            """
            define i64 @entry() {
            top:
                %aptr = alloca i64, i64 16
                %aint = ptrtoint i64* %aptr to i64
                ret i64 %aint
            }
            """,
            "entry",
        ), Int64, Tuple{})
        return Ptr{Cvoid}(int)
    end
end
