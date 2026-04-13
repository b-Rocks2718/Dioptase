# Memory Map (physical addresses)

Address range is 0x0000000 - 0x7FFFFFF

### 0x0000000 - 0x00003FF
Interrupt Vector Table

### 0x0000400 - ....
BIOS init. PC will be initialized to 0x00400 on startup

## 0x7FB8000 - 0x7FBBBFF
Audio output ring buffer. Fixed-size 16 KiB device-owned storage exposed through MMIO.

Notes:
- This region stores the PCM bytes consumed by the audio device configured through the `AUDIO_*` registers.
- The ring buffer base address is fixed at `0x7FB8000` and the ring size is fixed at `0x4000` bytes.
- The region is byte-addressable MMIO storage, not ordinary RAM.
- Software writes PCM sample bytes into this region and then advances `AUDIO_WRITE_IDX` to publish them to hardware.

## 0x7FBC000 - 0x7FBCFFF
Currently unmapped MMIO space reserved for future use.

## 0x7FBD000 - 0x7FBF57F
Tile framebuffer (tile entries).  
Two bytes per tile entry in an 80x60 grid (640x480 with 8x8 tiles).  
Lower byte: tile index.  
Upper byte: tile color (8-bit).  
The tile framebuffer is composited on top of the pixel framebuffer.  
Tile pixels with color 0xFXXX are transparent. Opaque tile pixels use packed 12-bit color with red in bits [3:0], green in bits [7:4], and blue in bits [11:8] (`0x0BGR` when written as hex nibbles).  
Tile pixels with color 0xCXXX are replaced by the tile color byte (currently interpreted as RGB332 and expanded to the same packed 12-bit format).  

## 0x7FC0000 - 0x7FE57FF
Pixel framebuffer. 320x240 resolution, 16-bit little-endian pixels (`0x0BGR`, 12-bit color: red in bits [3:0], green in [7:4], blue in [11:8]).  
This layer is drawn first and appears underneath the tile framebuffer.

### 0x7FE5800 - 0x7FE5801
PS/2 keyboard input stream (0 if nothing, otherwise ASCII)
Notes:
- Key make events return ASCII in the low byte.
- Key release events set bit 8 (value `0x0100`) in the returned 16-bit word.
- Enter is encoded as carriage return (`0x0D`).

### 0x7FE5802
UART TX

### 0x7FE5803
UART RX

### 0x7FE5804 - 0x7FE5807
PIT. Write a 32 bit value `n` and the timer will cause
an interrupt every `n` clock cycles (clock at 100MHz).  
In multicore configurations, the PIT countdown is shared across cores and advanced by core 0 only. Timer interrupts are delivered to all cores.

### 0x7FE5810 - 0x7FE5827
SD card 0 DMA engine.

Registers (all 32-bit, little-endian):

- 0x7FE5810 - 0x7FE5813: SD_DMA_MEM_ADDR  
  Physical memory byte address. The low 2 bits are ignored (address is 4-byte aligned).
- 0x7FE5814 - 0x7FE5817: SD_DMA_SD_BLOCK  
  SD card block address. Each block is 512 bytes.
- 0x7FE5818 - 0x7FE581B: SD_DMA_LEN  
  Transfer length in blocks.
  A length of 0 after truncation is an error.
- 0x7FE581C - 0x7FE581F: SD_DMA_CTRL  
  bit 0: START (self-clearing; writing 1 starts a transfer)  
  bit 1: DIR (0 = SD -> RAM, 1 = RAM -> SD)  
  bit 2: IRQ_EN (raise SD interrupt on completion)
  bit 3: SD_INIT (self-clearing; writing 1 initializes sd card)  
  other bits read as 0 and are ignored on write.
- 0x7FE5820 - 0x7FE5823: SD_DMA_STATUS  
  bit 0: BUSY  
  bit 1: DONE (set when transfer/init completes or is rejected due to error)  
  bit 2: ERR (set when error code != 0)  
  Writes to any byte clear DONE and ERR and also clear SD_DMA_ERR. BUSY is unaffected.
- 0x7FE5824 - 0x7FE5827: SD_DMA_ERR (read-only)  
  0 = no error  
  1 = START or SD_INIT while BUSY (ERR set, BUSY unchanged, DONE not set)  
  2 = zero length
  3 = DMA START before successful SD_INIT
  4 = SD init command/response failure (timeout or invalid response)
  5 = SD read block failure (timeout, missing data token/payload, or bad response)
  6 = SD write block failure (timeout or SD data-response reject)

Notes:
- DMA reads/writes physical memory addresses and MMIO side effects apply.
- DMA is non-atomic.
- Each completed memory beat transfers 4 bytes.
- A memory beat completes when the memory/cache fabric returns a completion handshake.
  This is not guaranteed to happen every clock tick.
- SD_INIT uses the same BUSY/DONE/ERR state machine as DMA.
- DMA START requires a successful SD_INIT after reset.
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

### 0x7FE5840 - 0x7FE5853
Audio output control block.

Registers (all 32-bit, little-endian):

- 0x7FE5840 - 0x7FE5843: AUDIO_CTRL  
  bit 0: ENABLE (1 = consume PCM data from the audio ring buffer, 0 = halt consumption and output silence)  
  bit 1: IRQ_EN (enable low-water interrupt delivery)  
  other bits read as 0 and are ignored on write.
- 0x7FE5844 - 0x7FE5847: AUDIO_STATUS (read-only)  
  bit 0: ENABLED (mirror of `AUDIO_CTRL.ENABLE`)  
  bit 1: LOW_WATER (set when buffered audio bytes are less than or equal to `AUDIO_WATERMARK`)  
  bit 2: UNDERRUN (set when playback is enabled and the device needs another sample while the buffer is empty; clears automatically when playback is disabled or software publishes at least one full sample again)  
  bit 3: IRQ_PENDING (set when `LOW_WATER` is set)  
  other bits read as 0.
- 0x7FE5848 - 0x7FE584B: AUDIO_WRITE_IDX  
  Software-owned producer byte index into the audio ring buffer. The device consumes bytes starting at `AUDIO_READ_IDX` up to, but not including, `AUDIO_WRITE_IDX`, wrapping at the end of the ring.
- 0x7FE584C - 0x7FE584F: AUDIO_READ_IDX (read-only)  
  Hardware-owned consumer byte index into the audio ring buffer. The device advances this register by 2 for each 16-bit sample consumed.
- 0x7FE5850 - 0x7FE5853: AUDIO_WATERMARK  
  Watermark in buffered bytes. `LOW_WATER` becomes 1 when the number of buffered bytes is less than or equal to this value.

Notes:
- The audio format is fixed at signed 16-bit little-endian mono PCM at 25,000 samples per second.
- `AUDIO_WRITE_IDX`, `AUDIO_READ_IDX`, and `AUDIO_WATERMARK` are byte counts, but audio samples are 16-bit. Software should keep them 2-byte aligned.
- `AUDIO_READ_IDX == AUDIO_WRITE_IDX` means the buffer is empty.
- To avoid ambiguity between empty and full, software must leave at least one 16-bit sample unused in the ring buffer.
- The audio interrupt is edge-triggered on the `LOW_WATER` transition from `0` to `1` while `AUDIO_CTRL.IRQ_EN` is `1`.
- Enabling `IRQ_EN` while `LOW_WATER` is already `1` does not synthesize an interrupt; software must observe the current status directly in that case.
- `UNDERRUN` is status-only and does not raise an interrupt.
- On underrun, the device outputs signed-zero samples (`0x0000`), leaves `AUDIO_READ_IDX` unchanged while the buffer is empty, and resumes playback automatically after software writes more data and advances `AUDIO_WRITE_IDX`.

## 0x7FE5B00 - 0x7FE5B3F
Sprite Coordinates.
Sprite 0 `x` coordinate at 0x7FE5B00 and 0x7FE5B01, `y` coordinate at 0x7FE5B02 and 0x7FE5B03,  
Sprite 1 `x` coordinate at 0x7FE5B04, and so on up to sprite 15.
Each `x`, `y` pair stores the coordinate of the top left corner of the sprite.

## 0x7FE5B40 - 0x7FE5B41
Tile horizontal scroll register (in pixels, signed 16-bit little-endian)

## 0x7FE5B42 - 0x7FE5B43
Tile vertical scroll register (in pixels, signed 16-bit little-endian)

## 0x7FE5B44
Tile scale register (tile layer pixels are displayed at 2\*\*n)

## 0x7FE5B50 - 0x7FE5B51
Pixel horizontal scroll register (in pixels, signed 16-bit little-endian)

## 0x7FE5B52 - 0x7FE5B53
Pixel vertical scroll register (in pixels, signed 16-bit little-endian)

## 0x7FE5B54
Pixel scale register (pixel layer pixels are displayed at 2\*\*(n+1))

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

## 0x7FE5B4C - 0x7FE5B4F
Clock divider register

## 0x7FE8000 - 0x7FEFFFF
Tilemap. Each tile is 8x8 pixels, 1 pixel takes 2 bytes (16-bit little-endian, opaque colors stored as `0x0BGR`).  
Pixels with 0xFXXX are transparent when drawn via the tile framebuffer.  
Pixels with 0xCXXX are the color that is stored with the tile in the framebuffer.
We reserve space for 256 tiles.

## 0x7FF0000 - 0x7FF7FFF
Sprite data. Each sprite is 32x32 pixels, and we reserve space for 16.
If there's an overlap, the higher sprite will appear on top (sprite 15 over sprite 0).
Sprite pixels use packed 12-bit color in the same `0x0BGR` format as the tile
and pixel framebuffers. Pixels with `0xFXXX` are transparent.
