# MOS Notes 2/25

## Kernel Modules

Have my_mod.o file

How to have kernel call functions in my_mod.o ?

Almost the same as dynamic libraries

my_mod.o must include a symbol table, mapping functions to their offsets

harder part is my_mod.o calling kernel functions (ex: malloc).  
Linker must fix the my_mod.o code to call the correct functions

Good use of kernel modules: device drivers
