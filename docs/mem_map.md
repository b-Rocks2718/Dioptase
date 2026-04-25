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
Synth audio device. Register-driven sound generator with 4 square-wave channels,
2 triangle-wave channels, and 2 noise channels. The synth output is mixed with
the existing PCM audio ring-buffer output before reaching the physical/host
audio sink. This synth device has no PCM channel of its own.

All synth registers are 32-bit, little-endian, and byte-addressable. Writes to
reserved bits are ignored and those bits read as 0. Addresses in this page that
are not assigned to a register read as 0 and ignore writes.

Global registers:

- 0x7FBC000 - 0x7FBC003: SYNTH_AUDIO_CTRL
  bit 0: ENABLE (1 = include synth output in the mixed audio stream, 0 = output signed-zero from this synth device)
  bit 1: RESET_STATE (write-1 strobe; resets synth control, master volume, and
  channel state, then applies the written ENABLE bit and self-clears; pending
  command-ring entries and the sample counter are preserved)
  other bits read as 0 and are ignored on write.
- 0x7FBC004 - 0x7FBC007: SYNTH_AUDIO_STATUS (read-only)
  bit 0: ENABLED (mirror of `SYNTH_AUDIO_CTRL.ENABLE`)
  bits 8-11: SQUARE0_ACTIVE through SQUARE3_ACTIVE
  bits 12-13: TRIANGLE0_ACTIVE through TRIANGLE1_ACTIVE
  bits 14-15: NOISE0_ACTIVE through NOISE1_ACTIVE
  A channel is active when its channel enable bit is set and either its length
  counter is disabled or its current length counter is nonzero.
- 0x7FBC008 - 0x7FBC00B: SYNTH_AUDIO_MASTER_VOLUME
  bits 7:0: master volume (0 = mute, 255 = full synth output)
  other bits read as 0 and are ignored on write. Reset value is 255.
- 0x7FBC00C - 0x7FBC00F: SYNTH_AUDIO_VERSION (read-only)
  Current value: 4.
- 0x7FBC010 - 0x7FBC013: SYNTH_AUDIO_CLOCK_HZ (read-only)
  Current value: 100000000.
- 0x7FBC014 - 0x7FBC017: SYNTH_AUDIO_SAMPLE_RATE_HZ (read-only)
  Current value: 25000.
- 0x7FBC018 - 0x7FBC01B: SYNTH_AUDIO_SAMPLE_COUNTER (read-only)
  Wrapping 32-bit count of synth output samples consumed by the device. This
  counter increments once per 25 kHz output sample whether or not
  `SYNTH_AUDIO_CTRL.ENABLE` is set, and `SYNTH_AUDIO_CTRL.RESET_STATE` does not
  reset it.

Synth command ring registers:

- 0x7FBC120 - 0x7FBC123: SYNTH_AUDIO_CMD_STATUS (read-only)
  bit 0: FULL (no free command-record slots are available; one record is always left unused to distinguish full from empty)
  bit 1: EMPTY (no pending command records)
  bit 2: LATE (sticky; at least one consumed command targeted a sample before
  the sample currently being rendered)
  bit 3: OVERFLOW (sticky; reserved for producer-overrun diagnostics; current
  hardware/software should avoid overrun by checking SPACE before publishing)
  bit 4: BAD_OFFSET (sticky; a consumed command used an invalid target register
  offset and was rejected)
  bit 5: BAD_FLAGS (sticky; a consumed command had nonzero reserved flags and
  was rejected)
  bits 19:8: pending command count
  bits 31:20: free command slots.
- 0x7FBC124 - 0x7FBC127: SYNTH_AUDIO_CMD_WRITE_IDX
  Software-owned producer byte index into the command ring. Software writes
  command records into the ring storage, then advances this register to publish
  them. Values are reduced modulo `SYNTH_AUDIO_CMD_RING_BYTES`, and low bits
  below the 16-byte command-record alignment are ignored.
- 0x7FBC128 - 0x7FBC12B: SYNTH_AUDIO_CMD_READ_IDX (read-only)
  Hardware-owned consumer byte index into the command ring. The device advances
  this register by 16 for each consumed command record.
- 0x7FBC12C - 0x7FBC12F: SYNTH_AUDIO_CMD_CTRL
  bit 0: RESET (write-1 strobe; resets READ_IDX and WRITE_IDX to 0 and clears
  sticky command-ring status flags)
  bit 1: CLEAR_FLAGS (write-1 strobe; clears LATE, OVERFLOW, BAD_OFFSET, and
  BAD_FLAGS without dropping pending command records)
  Reads return 0.
- 0x7FBC130 - 0x7FBC133: SYNTH_AUDIO_CMD_RING_BASE (read-only)
  Byte offset of command-ring storage within the synth page. Current value:
  `0x200`.
- 0x7FBC134 - 0x7FBC137: SYNTH_AUDIO_CMD_RING_BYTES (read-only)
  Current value: `0xE00`.
- 0x7FBC138 - 0x7FBC13B: SYNTH_AUDIO_CMD_RECORD_BYTES (read-only)
  Current value: `16`.

Synth command ring storage:

- 0x7FBC200 - 0x7FBCFFF: SYNTH_AUDIO_CMD_RING
  Byte-addressable command-ring storage. The region contains 224 16-byte command
  records. Because the ring leaves one record unused, software can publish at
  most 223 pending records at once.

Each 16-byte command record is little-endian:

| Offset | Field | Meaning |
| --- | --- | --- |
| `+0x00` | TARGET_SAMPLE | Absolute `SYNTH_AUDIO_SAMPLE_COUNTER` value |
| `+0x04` | REG_OFFSET | 32-bit aligned byte offset within the synth page |
| `+0x08` | VALUE | 32-bit value written to `REG_OFFSET` |
| `+0x0C` | FLAGS | Reserved; must be 0 |

Command ring timing and ordering:
- Software must publish commands in nondecreasing TARGET_SAMPLE order. Commands
  with the same TARGET_SAMPLE are applied in ring order.
- REG_OFFSET values at or above `0x120` are invalid command targets, so command
  records cannot recursively write command-ring control registers or storage.
- During each output sample, the device increments `SYNTH_AUDIO_SAMPLE_COUNTER`,
  consumes and applies all published commands whose TARGET_SAMPLE has been
  reached, then renders the sample from the resulting channel state.
- If a command target has already passed when the device consumes the record,
  the command is still applied after all earlier command records have applied.
  LATE records that this happened.
- `SYNTH_AUDIO_CTRL.RESET_STATE` resets control/channel state and master volume
  but does not drop pending command-ring records. Use
  `SYNTH_AUDIO_CMD_CTRL.RESET` to cancel pending commands.

Channel register blocks are 0x20 bytes each:

- 0x7FBC020 - 0x7FBC03F: SQUARE0
- 0x7FBC040 - 0x7FBC05F: SQUARE1
- 0x7FBC060 - 0x7FBC07F: SQUARE2
- 0x7FBC080 - 0x7FBC09F: SQUARE3
- 0x7FBC0A0 - 0x7FBC0BF: TRIANGLE0
- 0x7FBC0C0 - 0x7FBC0DF: TRIANGLE1
- 0x7FBC0E0 - 0x7FBC0FF: NOISE0
- 0x7FBC100 - 0x7FBC11F: NOISE1

Square channel registers, relative to each square block:

- +0x00: SQUARE_CTRL
  bit 0: ENABLE (0 = channel silent; writing 0 stops the channel)
  bit 1: LENGTH_ENABLE
  bits 5:4: DUTY (0 = 12.5%, 1 = 25%, 2 = 50%, 3 = 75%)
  other bits read as 0 and are ignored on write.
- +0x04: SQUARE_TIMER
  Sequencer period in 100 MHz device-clock ticks. A value `n` advances the
  8-step square sequencer every `n + 1` device ticks.
- +0x08: SQUARE_VOLUME
  bits 7:0: channel volume (0 = silent, 255 = full channel contribution)
- +0x0C: SQUARE_LENGTH
  Length reload in 25 kHz output samples. Used only when `LENGTH_ENABLE` is 1.
- +0x10: SQUARE_PHASE
  bits 2:0: current 8-step phase. Writes are reduced modulo 8.
- +0x14: SQUARE_TRIGGER
  bit 0: START (write-1 strobe; sets ENABLE, reloads the current length counter
  from `SQUARE_LENGTH`, resets phase to 0, and self-clears)
  Reads return 0.

Triangle channel registers, relative to each triangle block:

- +0x00: TRIANGLE_CTRL
  bit 0: ENABLE
  bit 1: LENGTH_ENABLE
  other bits read as 0 and are ignored on write.
- +0x04: TRIANGLE_TIMER
  Sequencer period in 100 MHz device-clock ticks. A value `n` advances the
  32-step triangle sequencer every `n + 1` device ticks.
- +0x08: TRIANGLE_VOLUME
  bits 7:0: channel volume.
- +0x0C: TRIANGLE_LENGTH
  Length reload in 25 kHz output samples. Used only when `LENGTH_ENABLE` is 1.
- +0x10: TRIANGLE_PHASE
  bits 4:0: current 32-step phase. Writes are reduced modulo 32.
- +0x14: TRIANGLE_TRIGGER
  bit 0: START (write-1 strobe; sets ENABLE, reloads the current length counter
  from `TRIANGLE_LENGTH`, resets phase to 0, and self-clears)
  Reads return 0.

Noise channel registers, relative to each noise block:

- +0x00: NOISE_CTRL
  bit 0: ENABLE
  bit 1: LENGTH_ENABLE
  bit 4: SHORT_MODE (0 = feedback from LFSR bit 1, 1 = feedback from LFSR bit 6)
  other bits read as 0 and are ignored on write.
- +0x04: NOISE_TIMER
  LFSR period in 100 MHz device-clock ticks. A value `n` advances the 15-bit
  LFSR every `n + 1` device ticks.
- +0x08: NOISE_VOLUME
  bits 7:0: channel volume.
- +0x0C: NOISE_LENGTH
  Length reload in 25 kHz output samples. Used only when `LENGTH_ENABLE` is 1.
- +0x10: NOISE_LFSR
  bits 14:0: current LFSR state. Writing 0 stores 1 instead.
- +0x14: NOISE_TRIGGER
  bit 0: START (write-1 strobe; sets ENABLE, reloads the current length counter
  from `NOISE_LENGTH`, normalizes a zero LFSR state to 1, and self-clears)
  Reads return 0.

Notes:
- The mixed audio output format remains signed 16-bit little-endian mono at
  25,000 samples per second.
- When `SYNTH_AUDIO_CTRL.ENABLE` is 0, synth channel phases, LFSR states, and
  length counters do not advance.
- `SYNTH_AUDIO_SAMPLE_COUNTER` still advances while `SYNTH_AUDIO_CTRL.ENABLE`
  is 0, so software can use it as the synth device's output-sample clock.
- Each synth output sample is generated from the current channel state, then
  each active channel advances by 4,000 device-clock ticks and length-enabled
  active channels decrement their length counter by 1.
- Square and noise channels output signed `+volume` or `-volume` before master
  scaling. Triangle channels output a centered 32-step triangle wave scaled by
  channel volume.
- The synth sample is computed as
  `clamp_i16(sum(channel_outputs) * 16 * SYNTH_AUDIO_MASTER_VOLUME / 255)`.
  The final audio sink receives `clamp_i16(pcm_sample + synth_sample)`.
- This synth device does not raise interrupts. The existing audio interrupt is
  still reserved for the PCM ring-buffer low-water condition.

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
PS/2 keyboard input stream (0 if nothing, otherwise guest key event)
Notes:
- Key make events return a guest keycode in the low byte.
- Key release events set bit 8 (value `0x0100`) in the returned 16-bit word and
  preserve the same low-byte guest keycode as the corresponding make event.
- Printable keys use the unshifted base-key ASCII identity in the low byte:
  letters are lowercase ASCII, the number row is `'0'` .. `'9'`, and punctuation
  uses the unshifted base key (`'-'`, `'='`, `'['`, `']'`, `'\\'`, `';'`,
  apostrophe, grave accent, `','`, `'.'`, `'/'`, and space).
- Control keys that already have standard ASCII control bytes keep those values:
  Backspace = `0x08`, Tab = `0x09`, Enter = `0x0D`, Escape = `0x1B`, Delete =
  `0x7F`.
- Modifiers use distinct left/right keycodes:
  - Left Ctrl = `0xE0`
  - Left Shift = `0xE1`
  - Left Alt = `0xE2`
  - Right Ctrl = `0xE4`
  - Right Shift = `0xE5`
  - Right Alt = `0xE6`
- Common non-printable keys use a reserved keycode range so they do not collide
  with printable ASCII:
  - Insert = `0x80`
  - Home = `0x81`
  - Page Up = `0x82`
  - End = `0x83`
  - Page Down = `0x84`
  - Right = `0x85`
  - Left = `0x86`
  - Down = `0x87`
  - Up = `0x88`
  - F1 = `0x90` through F12 = `0x9B`
- Numeric keypad digits/operators may be normalized by the input frontend to
  the corresponding base guest keycodes. Distinct numpad-only guest codes are
  currently unspecified.

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
PCM audio output control block.

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
