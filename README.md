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
* SW[0] - RESET
* SW[16] - joystick_0_A, SW[15] - joystick_0_B, SW[14] - joystick_0_C, SW[13] - joystick_0_START, SW[12] - joystick_0_Left twin at debug time (like KEY[0])
* KEY[0] - joystick_0_Right and RESET (01052021), KEY[3] - joystick_0_Left, KEY[2] - joystick_0_Up, KEY[1] - joystick_0_Down
