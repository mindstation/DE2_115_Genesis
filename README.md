# [SEGA Megadrive/Genesis](https://en.wikipedia.org/wiki/Sega_Genesis) for Terasic DE2-115 board.

This is the port of the [Genesis_MiSTer](https://github.com/MiSTer-devel/Genesis_MiSTer) core.
Genesis_MiSTer is based on fpgagen.

fpgagen - a SEGA Megadrive/Genesis clone in a FPGA.
Copyright (c) 2010-2013 Gregory Estrade (greg@torlus.com)
All rights reserved


## Installing

Write ROM to Flash memory of the DE2-115 by "Terasic-DE2-115 Control Panel":
* erase Flash chip
* in Sequential Write block set "File Length" option
* in Sequential Write block select ROM file

Load output_files/DE2_115_Genesis.sof to the board. ROM image will be copied automatically from Flash to SDRAM, while LEDR0 is glowing.
 
ROM size will be taken from the ROM header. Only exception is Super Street Fighter 2 New Challengers. SSF2 NC has hardcoded 5 MB size in the core.


## Keys

* SW[16] - RESET
* SW[5] - joystick_0_B, SW[4] - joystick_0_C, SW[3] - joystick_0_Left, SW[2] - joystick_0_Up, SW[1] - joystick_0_Down, SW[0] - joystick_0_Right
* KEY[3] - joystick_0_START, KEY[2] - joystick_0_A
* SW[12] - joystick_1_B, SW[11] - joystick_1_C, SW[10] - joystick_1_Left, SW[9] - joystick_1_Up, SW[8] - joystick_1_Down, SW[7] - joystick_1_Right
* KEY[1] - joystick_1_START, KEY[0] - joystick_1_A


## Gamepads

Master System or compatible gamepads can be connected to the GPIO with 3.3V pull-up resistors.
See connection diagram in "schematics/DE2-115 Master System gamepads adapter.pdf"

JP5 pin 15, JP5 pin 19, JP5 pin 23, JP5 pin 27, JP5 pin 33, JP5 pin 37 - SMS gamepad 1 (21UDLR, active low)
JP5 pin  2, JP5 pin 4,  JP5 pin 6,  JP5 pin 8,  JP5 pin 10, JP5 pin 14 - SMS gamepad 2 (21UDLR, active low)

Where SMS gamepad button 1 is Genesis B button.
SMS gamepad button 2 is Genesis C button.


## Files description

File name                                               | File description
--------------------------------------------------------|----------------------------------------------------------------------------
de2115_board                                            | The folder holds a DE2-115 specific modules
output_files/DE2_115_Genesis.sof                        | FPGA configuration for loading by JTAG
rtl                                                     | The core modules
schematics/DE2-115 Master System gamepads adapter.pdf   | Master System gamepads connection diagram
simulation/testbench                                    | Project testbenches, run a "*.do" script in Altera ModelSim
sys                                                     | MiSTER framework modules (it is project top-level module)
DE2_115_Genesis.qpf                                     | Main Quartus project file
DE2_115_Genesis.qsf                                     | Quartus project settings file
Genesis.sdc                                             | Constraints for the core
Genesis.sv                                              | Top-level module of the core
LICENSE                                                 | GPL-3.0 License
README.md                                               | This readme file
files.qip                                               | The core files list (Quartus IP file)


## Known issues

* Virtual Racing does not work.
* No Save RAM backup.
