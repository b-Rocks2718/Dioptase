# Dioptase ABI

- `r0`: reserved (always zero)
- `r1`: return value 
- `r1-r8`: arg0 - arg7, with additional args passed on the stack
- `r9-r19`: additional caller-saved registers
- `r20-r27`: callee-saved registers
- `r28` - will eventually be used as TLS base
- `r29` - return address
- `r30` - base pointer
- `r31` - stack pointer 
