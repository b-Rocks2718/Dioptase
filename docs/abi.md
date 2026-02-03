# Dioptase ABI

## Registers
- `r0`: always zero, enforced by hardware
- `r1-r2`: return value (`r1` only if the value fits in a single register)
- `r1-r8`: arg0 - arg7, with additional args passed on the stack
- `r9-r19`: additional caller-saved registers
- `r20-r27`: callee-saved registers
- `r28`: will eventually be used as TLS base
- `r29`: return address
- `r30`: base pointer
- `r31`: stack pointer 

## Stack Frame Structure

Stack pointer and base pointer are expected to stay 4-byte aligned

```
addr -> mem
--------------
...  -> ...
bp+12-> arg 9
bp+8 -> arg 8
bp+4 -> return addr
bp   -> old bp
bp-4 -> local 1
bp-8 -> local 2
...  -> ...
sp   -> local n
```

First 8 args are passed in r1-r8, remaining args are pushed in reverse order. ra is pushed, bp is pushed, bp is replaced with the current sp, and the call instruction places the return address in r31. The result is that arguments are above the new bp, and local variables are below it. 

In assembly:

- caller does
  ```
  # push stack args
  push <argN>
  ...
  push <arg9>
  push <arg8>

  # move reg args
  mov  r8, <arg7>
  ...
  mov  r2, <arg1>
  mov  r1, <arg0>
  
  call func # will place return address in r29
  # return value now in r1
  
  # deallocate stack args
  add  sp, sp, <num-stack-args> 
  ```

- function prologue is
  ```
  func:
    push ra            # put ra on the stack
    push bp            # put bp on the stack
    mov  bp sp          # move bp to new frame

    # func body here
  ```

- function epilogue is
  ```
    # func body here

    mov  sp bp         # deallocate local vars
    lwa  ra [bp, 4]    # load return address
    lwa  bp [bp]       # load previous base pointer
    add  sp sp 8       # deallocate ra and bp on stack
    ret
  ```

### Struct conventions

#### Returning structs
If a struct fits into one register, it is returned in `r1`. If it fits in two, it is returned in `r1` and `r2`. Otherwise, the caller must allocate space for the return value and pass a pointer to the callee in `r1` (shifting other function arguments to the remaining registers).

#### Struct arguments
If a struct fits into a single register and there is a register available, the struct arguement is passed in that register. If a struct fits into two registers and two registers are available, the struct argument is passed in those two registers. Otherwise the struct is passed on the stack. Arguments that come after the struct will be passed in registers if any remain, regardless of if the struct is passed in registers or on the stack. 

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
