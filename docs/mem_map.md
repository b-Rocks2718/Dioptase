# Memory Map (physical addresses)

Address range is 0x0000000 - 0x7FFFFFF

### 0x0000000 - 0x00003FF
Interrupt Vector Table

### 0x0000400 - ....
Kernel init. PC will be initialized to 0x00400 on startup

### 0x7FF0000 - 0x7FF0001
Input stream from PS/2 keyboard (0 if nothing, otherwise ASCII)

### 0x7FF0002
UART TX

### 0x7FF0003
UART RX

### 0x7FF0004 - 0x7FF0007
PIT. Write a 32 bit value `n` and the timer will cause
an interrupt every `n` clock cycles (clock at 100MHz).

### 0x7FF01F9 - 0x7FF03FF
SD card. 0x7FF0200 - 0x7FF03FF is a 512 byte buffer for reading and writing. 0x7FF01FA - 0x7FF01FF is a 6 byte buffer used to form a command. When 0x7FF01F9 is written to, the command is sent. Reading 0x7FF01F9 returns `0x01` while the controller is busy and `0x00` once it is idle. SD card sends an interrupt when it is done.

## 0x7FF6000 - 0x7FF9FFF
Sprite data. Each sprite is 32x32 pixels, and we reserve space for 8.
If there's an overlap, the higher sprite will appear on top (sprite 7 over sprite 0).

## 0x7FFA000 - 0x7FFDFFF
Tilemap. Each tile is 8x8 pixels, 1 pixel takes 2 bytes (12 bits), and we reserve space for 128

## 0x7FFE000 - 0x7FFFFFF
Framebuffer. The plan is to use 640x480 resolution, so we need 4800 tiles = 0x12C0 bytes.

## 0x7FFFFD0 - 0x7FFFFEF
Sprite Coordinates.
Sprite 0 `x` coordinate at 0x7FFFFD0 and 0x2FFD1, `y` coordinate at 0x7FFFFD2 and 0x7FFFFD3,  
Sprite 1 `x` coordinate at 0x7FFFFD4, and so on.
Each `x`, `y` pair stores the coordinate of the bottom left corner of the sprite.

## 0x7FFFFFB
Scale register (all screen items are displayed at 2\*\*n)

## 0x7FFFFFC - 0x7FFFFFD
Horizontal scroll register (in pixels)

## 0x7FFFFFE - 0x7FFFFFF
Vertical scroll register (in pixels)
