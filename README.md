# [SEGA Megadrive/Genesis](https://en.wikipedia.org/wiki/Sega_Genesis) for Terasic DE2-115 board.

This is the port of the [Genesis_MiSTer](https://github.com/MiSTer-devel/Genesis_MiSTer) core.

Genesis_MiSTer is based on fpgagen.
fpgagen - a SEGA Megadrive/Genesis clone in a FPGA.
Copyright (c) 2010-2013 Gregory Estrade (greg@torlus.com)
All rights reserved


## Installing
Write ROM to Flash memory of the DE2-115 by DE2_115_control_panel.
Load output_files/DE2_115_Genesis.sof to the board. ROM will be copied from Flash to SDRAM while LEDR[0] lights.

## Keys
* F1 - reset to JP(NTSC) region
* F2 - reset to US(NTSC) region
* F3 - reset to EU(PAL)  region


## Auto Region option
There are 2 versions of region detection:

1) File name extension:

* BIN -> JP
* GEN -> US
* MD  -> EU

2) Header. It may not always work as not all ROMs follow the rule, especially in European region.
The header may include several regions - the correct one will be selected depending on priority option.


## Additional features

* Multitaps: 4-way, Team player, J-Cart
* SVP chip (Virtua Racing)
* Audio Filters for Model 1, Model 2, Minimal, No Filter.
* Option to choose between YM2612 and YM3438 (changes Ladder Effect behavior).
* Composite Blending, smooth dithering patterns in games.
* Sprite Limit, enables more sprites.
* CPU Turbo, mitigates slowdowns.
