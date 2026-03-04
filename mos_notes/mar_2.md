# MOS Notes 3/2

## Goal of Systems is Developer Experience

UNIX treats everything like a file

File interface:
- read
- write
- open
- close
- mmap
- ioctl (handles everything that's not a file)

Real GPU interface:
- load program
- execute program
- halt program

Issue: hard to optimize ioctl

UNIX philosophy:
- programs do exactly one thing
- expect output of any program to be the input of another (have simple interfaces)
- design software so it can be tested early
- build tools to do things for you



