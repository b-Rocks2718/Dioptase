# Memory Map (physical addresses)

Address range is 0x0000000 - 0x7FFFFFF

### 0x0000000 - 0x00003FF
Interrupt Vector Table

### 0x0000400 - ....
Kernel init. PC will be initialized to 0x00400 on startup

## 0x7FC0000 - 0x7FE57FF
Framebuffer. The plan is to use 640x480 mode for the VGA, but actually do 320x240 resolution.  
320x240x2 = 0x25800 bytes. The graphics hardware can also be set to a tile mode with 8x8 tiles  

### 0x7FE5800 - 0x7FE5801
PS/2 keyboard input stream (0 if nothing, otherwise ASCII)

### 0x7FE5802
UART TX

### 0x7FE5803
UART RX

### 0x7FE5804 - 0x7FE5807
PIT. Write a 32 bit value `n` and the timer will cause
an interrupt every `n` clock cycles (clock at 100MHz).

### 0x7FE58F9 - 0x7FE5AFF
SD card. 0x7FE5900 - 0x7FE5AFF is a 512 byte buffer for reading and writing. 0x7FE58FA - 0x7FE58FF is a 6 byte buffer used to form a command. When 0x7FE58F9 is written to, the command is sent. Reading 0x7FE58F9 returns `0x01` while the controller is busy and `0x00` once it is idle. SD card sends an interrupt when it is done.

## 0x7FE5B00 - 0x7FE5B3F
Sprite Coordinates.
Sprite 0 `x` coordinate at 0x7FE5B00 and 0x7FE5B01, `y` coordinate at 0x7FE5B02 and 0x7FE5B03,  
Sprite 1 `x` coordinate at 0x7FE5B04, and so on up to sprite 15.
Each `x`, `y` pair stores the coordinate of the bottom left corner of the sprite.

## 0x7FE5B40 - 0x7FE5B41
Horizontal scroll register (in pixels)

## 0x7FE5B42 - 0x7FE5B43
Vertical scroll register (in pixels)

## 0x7FE5B44
Scale register (all screen items are displayed at 2\*\*n)

## 0x7FE5B45
Graphics mode register (0 => tile mode, 1 => pixel mode)

## 0x7FE5B46
VGA status register (Read-only)  
bit 0: in vblank  
bit 1: in hblank  
VGA will send an interrupt when entering the vblank region  

## 0x7FE5B48 - 0x7FE5B4B
VGA frame count register (Read-only)  
increments once per frame  
@ 60Hz this takes > 2 years to overflow

## 0x7FE8000 - 0x7FEFFFF
Tilemap. Each tile is 8x8 pixels, 1 pixel takes 2 bytes, and we reserve space for 256

## 0x7FF0000 - 0x7FF7FFF
Sprite data. Each sprite is 32x32 pixels, and we reserve space for 16.
If there's an overlap, the higher sprite will appear on top (sprite 7 over sprite 0).
