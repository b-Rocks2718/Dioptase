# MOS Notes 2/18

`/proc` is a synthetic filesystem  
contains "files" for each running process    
has other special "files" like `uptime`  
reading from `uptime` prints how long the system has been running  
reading from a process print the PCB  

this is implemented with dynamic dispatch, so different kinds of nodes can have their own `read()` implementations


loadable kernel modules - implementation is similar to user mode programs, but you run the loaded program

## Kernel design decisions


