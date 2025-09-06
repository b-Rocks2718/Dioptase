# Memory Map (physical addresses)

## 0x00000 - 0x1FFFF

### 0x00000 - 0x003FF
Interrupt Vector Table

### 0x00400 - 0x0FFFF

Code, heap, stack  
Code will start at 0x00400, stack at 0x0FFFF  
Heap is everything in between
Kernel will probably use this memory for itself

PC will be initialized to 0x00400 on startup

### 0x10000 - 0x1FFFF
Kernel will probably give this space to user processes

## 0x20000 - 0x25FFF
General I/O (will include SD card at some point).

### 0x20000 - 0x20001
Input stream from PS/2 keyboard (0 if nothing, otherwise ASCII)

### 0x20002
UART TX

### 0x20004 - 0x20008
SD card (IDK exactly what the interface will be yet)

## 0x26000 - 0x29FFF
Sprite data. Each sprite is 32x32 pixels, and we reserve space for 8.
If there's an overlap, the higher sprite will appear on top (sprite 7 over sprite 0).

## 0x2A000 - 0x2DFFF
Tilemap. Each tile is 8x8 pixels, 1 pixel takes 2 bytes (12 bits), and we reserve space for 128

## 0x2E000 - 0x2FFFF
Framebuffer. The plan is to use 640x480 resolution, so we need 4800 tiles = 0x12C0 bytes.

## 0x2FFD0 - 0x2FFEF
Sprite Coordinates.
Sprite 0 `x` coordinate at 0x2FFD0 and 0x2FFD1, `y` coordinate at 0x2FFD2 and 0x2FFD3,  
Sprite 1 `x` coordinate at 0x2FFD4, and so on.
Each `x`, `y` pair stores the coordinate of the bottom left corner of the sprite.

## 0x2FFFB
Scale register (all screen items are displayed at 2\*\*n)

## 0x2FFFC - 0x2FFFD
Horizontal scroll register (in pixels)

## 0x2FFFE - 0x2FFFF
Vertical scroll register (in pixels)
