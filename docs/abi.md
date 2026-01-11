# Dioptase ABI

## Registers
- `r0`: always zero, enforced by hardware
- `r1`: return value 
- `r1-r8`: arg0 - arg7, with additional args passed on the stack
- `r9-r19`: additional caller-saved registers
- `r20-r27`: callee-saved registers
- `r28`: will eventually be used as TLS base
- `r29`: return address
- `r30`: base pointer
- `r31`: stack pointer 

## Stack Frame Structure

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
    swa  ra [sp, -4]   # put ra on the stack
    swa  bp [sp, -8]   # put bp on the stack
    add  sp sp -8       # correct sp
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
