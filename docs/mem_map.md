# Memory Map (physical addresses)

Address range is 0x0000000 - 0x7FFFFFF

### 0x0000000 - 0x00003FF
Interrupt Vector Table

### 0x0000400 - ....
BIOS init. PC will be initialized to 0x00400 on startup

## 0x7FBD000 - 0x7FBD257F
Tile framebuffer (tile entries).  
Two bytes per tile entry in an 80x60 grid (640x480 with 8x8 tiles).  
Lower byte: tile index.  
Upper byte: tile color (8-bit).  
The tile framebuffer is composited on top of the pixel framebuffer.  
Tile pixels with color 0xFXXX are transparent (12-bit RGB stored in a 16-bit entry).  
Tile pixels with color 0xCXXX are replaced by the tile color byte (currently interpreted as RGB332 and expanded to 12-bit RGB in the emulator).  

## 0x7FC0000 - 0x7FE57FF
Pixel framebuffer. 320x240 resolution, 16-bit little-endian pixels (0x0RGB, 12-bit color).  
This layer is drawn first and appears underneath the tile framebuffer.

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

### 0x7FE5810 - 0x7FE5827
SD card 0 DMA engine (no data buffer). DMA is non-atomic and advances 4 bytes per clock tick.

Registers (all 32-bit, little-endian):

- 0x7FE5810 - 0x7FE5813: SD_DMA_MEM_ADDR  
  Physical memory byte address. The low 2 bits are ignored (address is 4-byte aligned).
- 0x7FE5814 - 0x7FE5817: SD_DMA_SD_BLOCK  
  SD card block address. Each block is 512 bytes.
- 0x7FE5818 - 0x7FE581B: SD_DMA_LEN  
  Transfer length in bytes. The low 2 bits are ignored (length is rounded down to a multiple of 4).  
  A length of 0 after truncation is an error.
- 0x7FE581C - 0x7FE581F: SD_DMA_CTRL  
  bit 0: START (self-clearing; writing 1 starts a transfer)  
  bit 1: DIR (0 = SD -> RAM, 1 = RAM -> SD)  
  bit 2: IRQ_EN (raise SD interrupt on completion)  
  other bits read as 0 and are ignored on write.
- 0x7FE5820 - 0x7FE5823: SD_DMA_STATUS  
  bit 0: BUSY  
  bit 1: DONE (set when transfer completes or is rejected due to error)  
  bit 2: ERR (set when error code != 0)  
  Writes to any byte clear DONE and ERR and also clear SD_DMA_ERR. BUSY is unaffected.
- 0x7FE5824 - 0x7FE5827: SD_DMA_ERR (read-only)  
  0 = no error  
  1 = START while BUSY (ERR set, BUSY unchanged, DONE not set)  
  2 = zero length (after truncation)

Notes:
- DMA reads/writes physical memory addresses and MMIO side effects apply.
- Transfers can span multiple SD blocks starting from SD_DMA_SD_BLOCK.
- SD card 0 interrupt is asserted when a transfer completes and IRQ_EN is set (including completion with ERR).

### 0x7FE5828 - 0x7FE583F
SD card 1 DMA engine. Register layout and behavior match SD card 0 with the following addresses:

- 0x7FE5828 - 0x7FE582B: SD1_DMA_MEM_ADDR  
- 0x7FE582C - 0x7FE582F: SD1_DMA_SD_BLOCK  
- 0x7FE5830 - 0x7FE5833: SD1_DMA_LEN  
- 0x7FE5834 - 0x7FE5837: SD1_DMA_CTRL  
- 0x7FE5838 - 0x7FE583B: SD1_DMA_STATUS  
- 0x7FE583C - 0x7FE583F: SD1_DMA_ERR

Notes:
- SD card 1 interrupt is asserted when a transfer completes and IRQ_EN is set (including completion with ERR).

## 0x7FE5B00 - 0x7FE5B3F
Sprite Coordinates.
Sprite 0 `x` coordinate at 0x7FE5B00 and 0x7FE5B01, `y` coordinate at 0x7FE5B02 and 0x7FE5B03,  
Sprite 1 `x` coordinate at 0x7FE5B04, and so on up to sprite 15.
Each `x`, `y` pair stores the coordinate of the bottom left corner of the sprite.

## 0x7FE5B40 - 0x7FE5B41
Tile horizontal scroll register (in pixels)

## 0x7FE5B42 - 0x7FE5B43
Tile vertical scroll register (in pixels)

## 0x7FE5B44
Tile scale register (tile layer pixels are displayed at 2\*\*n)

## 0x7FE5B50 - 0x7FE5B51
Pixel horizontal scroll register (in pixels)

## 0x7FE5B52 - 0x7FE5B53
Pixel vertical scroll register (in pixels)

## 0x7FE5B54
Pixel scale register (pixel layer pixels are displayed at 2\*\*n)

## 0x7FE5B60 - 0x7FE5B6F
Sprite scale registers (one byte per sprite, 2\*\*n scaling)

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
Tilemap. Each tile is 8x8 pixels, 1 pixel takes 2 bytes (16-bit little-endian, 0x0RGB).  
Pixels with 0xFXXX are transparent when drawn via the tile framebuffer.  
Pixels with 0xCXXX are the color that is stored with the tile in the framebuffer.
We reserve space for 256 tiles.

## 0x7FF0000 - 0x7FF7FFF
Sprite data. Each sprite is 32x32 pixels, and we reserve space for 16.
If there's an overlap, the higher sprite will appear on top (sprite 7 over sprite 0).
