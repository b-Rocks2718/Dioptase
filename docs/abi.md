# Dioptase ABI

- `r31` - stack pointer 
- `r30` - base pointer
- `r29` - return address
- `r28` - will eventually be used as TLS base
- `r1`  - return value 

## Calling conventions
For now, `r1` is caller saved and all other registers are callee saved
