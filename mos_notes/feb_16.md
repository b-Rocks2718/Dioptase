# MOS Notes 2/16

## Slab Allocator

Used for heap

Slab: array of pages, partitioned into units of a fixed size

First n bytes of each slab is metadata (n = 64 in this example).  
Metadata includes free list.

Rest of slab is partitioned into objects of fixed size

Free list: pointer to first free object.  
Free object isn't being used, so it can store a pointer to the next free object

Safety: Each core owns a slab of each object size

Slab sizes: 16, 32, ..., 512, 1024

Issue with per-core slabs: thread can malloc on one core and free on another

Solution: magic with atomic compare-and-swap (I don't get all the details)
also global caches  


