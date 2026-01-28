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
In multicore configurations, the PIT countdown is shared across cores and advanced by core 0 only. Timer interrupts are delivered to all cores.

### 0x7FE58F0 - 0x7FE5907
SD card 0 DMA engine (no data buffer). DMA is non-atomic and advances 4 bytes per clock tick.

Registers (all 32-bit, little-endian):

- 0x7FE58F0 - 0x7FE58F3: SD_DMA_MEM_ADDR  
  Physical memory byte address. The low 2 bits are ignored (address is 4-byte aligned).
- 0x7FE58F4 - 0x7FE58F7: SD_DMA_SD_BLOCK  
  SD card block address. Each block is 512 bytes.
- 0x7FE58F8 - 0x7FE58FB: SD_DMA_LEN  
  Transfer length in bytes. The low 2 bits are ignored (length is rounded down to a multiple of 4).  
  A length of 0 after truncation is an error.
- 0x7FE58FC - 0x7FE58FF: SD_DMA_CTRL  
  bit 0: START (self-clearing; writing 1 starts a transfer)  
  bit 1: DIR (0 = SD -> RAM, 1 = RAM -> SD)  
  bit 2: IRQ_EN (raise SD interrupt on completion)  
  other bits read as 0 and are ignored on write.
- 0x7FE5900 - 0x7FE5903: SD_DMA_STATUS  
  bit 0: BUSY  
  bit 1: DONE (set when transfer completes or is rejected due to error)  
  bit 2: ERR (set when error code != 0)  
  Writes to any byte clear DONE and ERR and also clear SD_DMA_ERR. BUSY is unaffected.
- 0x7FE5904 - 0x7FE5907: SD_DMA_ERR (read-only)  
  0 = no error  
  1 = START while BUSY (ERR set, BUSY unchanged, DONE not set)  
  2 = zero length (after truncation)

Notes:
- DMA reads/writes physical memory addresses and MMIO side effects apply.
- Transfers can span multiple SD blocks starting from SD_DMA_SD_BLOCK.
- SD card 0 interrupt is asserted when a transfer completes and IRQ_EN is set (including completion with ERR).

### 0x7FE5908 - 0x7FE591F
SD card 1 DMA engine. Register layout and behavior match SD card 0 with the following addresses:

- 0x7FE5908 - 0x7FE590B: SD1_DMA_MEM_ADDR  
- 0x7FE590C - 0x7FE590F: SD1_DMA_SD_BLOCK  
- 0x7FE5910 - 0x7FE5913: SD1_DMA_LEN  
- 0x7FE5914 - 0x7FE5917: SD1_DMA_CTRL  
- 0x7FE5918 - 0x7FE591B: SD1_DMA_STATUS  
- 0x7FE591C - 0x7FE591F: SD1_DMA_ERR

Notes:
- SD card 1 interrupt is asserted when a transfer completes and IRQ_EN is set (including completion with ERR).

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

## 7FE5B4C - 7FE5B4F
Clock divider register

## 0x7FE8000 - 0x7FEFFFF
Tilemap. Each tile is 8x8 pixels, 1 pixel takes 2 bytes, and we reserve space for 256

## 0x7FF0000 - 0x7FF7FFF
Sprite data. Each sprite is 32x32 pixels, and we reserve space for 16.
If there's an overlap, the higher sprite will appear on top (sprite 7 over sprite 0).
