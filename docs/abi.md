# Dioptase ABI

## Register
- `r0`: reserved (always zero)
- `r1`: return value 
- `r1-r8`: arg0 - arg7, with additional args passed on the stack
- `r9-r19`: additional caller-saved registers
- `r20-r27`: callee-saved registers
- `r28`: will eventually be used as TLS base
- `r29`: return address
- `r30`: base pointer
- `r31`: stack pointer 

## Types
Signed/unsigned versions of each type share the same size.  

`char`: 1 byte
`short`: 2 bytes
`int`: 4 bytes
`long`: 8 bytes
`long long`: 16 bytes

`float`: 4 bytes
`double`: 8 bytes
`long double`: 16 bytes

`void*`: 4 bytes
