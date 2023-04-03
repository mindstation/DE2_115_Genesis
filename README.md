# [SEGA Megadrive/Genesis](https://en.wikipedia.org/wiki/Sega_Genesis) for Terasic DE2-115 board.

Русскую версию README смотрите в [README_RUS.md](https://github.com/mindstation/DE2_115_Genesis/blob/de2115porting/README_RUS.md)

This is the port of the [Genesis_MiSTer](https://github.com/MiSTer-devel/Genesis_MiSTer) core.

Genesis_MiSTer is based on fpgagen.

fpgagen - a SEGA Megadrive/Genesis clone in a FPGA for Terasic DE2, MiST and Turbo Chameleon 64. Copyright (c) 2010-2013 Gregory Estrade (greg@torlus.com)
All rights reserved

The project DE2_115_Genesis was created with Quartus Prime 17.0.2 Lite Edition.


## Installing

Write ROM to a FLASH memory of the DE2-115 by "Terasic-DE2-115 Control Panel":

1. select FLASH memory type
2. erase FLASH chip (repeat before every ROM write)
3. in Sequential Write block set "File Length" option
4. in Sequential Write block open ROM file using "Write a File to Memory" button

Load "output_files/DE2_115_Genesis.sof" to the board. ROM image will copying automatically from FLASH to SDRAM when LEDR0 lights up.
ROM runs automatically after its had copied and LEDR0 gone out.
 
ROM size is set by the ROM header. Only exception is Super Street Fighter 2 New Challengers. SSF2 NC has hardcoded 5 MB size in the core.


## Board keys

* SW[16] - Genesis RESET
* SW[5]  - joystick_0_B, SW[4] - joystick_0_C, SW[3] - joystick_0_Left, SW[2] - joystick_0_Up, SW[1] - joystick_0_Down, SW[0] - joystick_0_Right
* KEY[3] - joystick_0_START, KEY[2] - joystick_0_A
* SW[12] - joystick_1_B, SW[11] - joystick_1_C, SW[10] - joystick_1_Left, SW[9] - joystick_1_Up, SW[8] - joystick_1_Down, SW[7] - joystick_1_Right
* KEY[1] - joystick_1_START, KEY[0] - joystick_1_A


## Gamepads

### Genesis and Mega Drive gamepads 

3 or 6 buttons gamepad can be connected to GPIO. No support for other accessories.

See connection diagram in "schematics/DE2-115 Genesis and Mega Drive gamepads 3V3 adapter.pdf" for a simple 3.3V connection, or 
"schematics/DE2-115 Genesis and Mega Drive gamepads 5V adapter.pdf" for a 5V connection with a Logic Level Converter chip SN74LVC244A.

GPIO 3.3V connection list for player 1 and player 2 gamepads:

* JP5 pin 15, JP5 pin 19, JP5 pin 23, JP5 pin 27, JP5 pin 29, JP5 pin 30, JP5 pin 33, JP5 pin 37, JP5 pin 39 - gamepad 1 (C/Start, B/A, Up/Z, Down/Y, 3.3V, GND, Left/X, Right/Mode, Select)
* JP5 pin 2, JP5 pin 4, JP5 pin 6, JP5 pin 8, JP5 pin 10, JP5 pin 12, JP5 pin 14, JP5 pin 16, JP5 pin 29 - gamepad 2 (C/Start, B/A, Up/Z, Down/Y, Left/X, GND, Right/Mode, Select, 3.3V)

Mega Drive and Genesis 6-buttons gamepad pinout list (3.3V power):

pin 1 - Up/Z, pin 2 - Down/Y, pin 3 - Left/X, pin 4 - Right/Mode, pin 5 - 3.3V,
pin 6 - B/A, pin 7 - "Select" buttons set, pin 8 - GND, pin 9 - C/Start

Contact numbering at gamepad connector is from right to left by rows. The first right pin in the upper row is pin 1. The last one is pin 5. The first right pin in the bottom row is pin 6. The last one is pin 9.

Most Genesis and Mega Drive gamepads work fine with 3.3V power. If your gamepads don't, then try 5V connection scheme.

### Master System or compatible gamepads 

They can be connected also to the GPIO. Gamepads need 3.3V pull-up resistors. Project uses an internal weak pull-up the FPGA. No power needs for the gamepad.
See connection diagram in "schematics/DE2-115 Master System gamepads adapter.pdf".

No support for other Master System accessories.

GPIO connection list for player 1 and player 2 gamepads:

* JP5 pin 15, JP5 pin 19, JP5 pin 23, JP5 pin 27, JP5 pin 30, JP5 pin 33, JP5 pin 37 - SMS gamepad 1 (Button 2, Button 1, Up, Down, GND, Left, Right; active low)
* JP5 pin 2, JP5 pin 4, JP5 pin 6, JP5 pin 8, JP5 pin 10, JP5 pin 12, JP5 pin 14 - SMS gamepad 2 (Button 2, Button 1, Up, Down, Left, GND, Right; active low)

Master System gamepad pinout:

pin 1 - Up, pin 2 - Down, pin 3 - Left, pin 4 - Right, pin 6 - Button 1, pin 8 - GND, pin 9 - Button 2

Contact numbering at gamepad connector is from right to left by rows. The first right pin in the upper row is pin 1. The last one is pin 5. The first right pin in the bottom row is pin 6. The last one is pin 9.

Where button 1 of SMS gamepad is used as B Genesis button.
Button 2 of SMS gamepad is used as C Genesis button.


## Files description

File name                                               | File description
--------------------------------------------------------|----------------------------------------------------------------------------
de2115_board                                            | The folder holds DE2-115 specific modules
output_files/DE2_115_Genesis.sof                        | FPGA configuration for loading by JTAG
output_files/DE2_115_Genesis.jic                        | Persistent FPGA configuration
rtl                                                     | The Genesis/Mega Drive core modules
schematics                                              | Genesis and Master System gamepads connection diagrams
simulation/testbench                                    | Project testbenches, open a "*.do" script in Altera ModelSim for simulation
sys                                                     | MiSTER framework modules (the project top-level module is here)
DE2_115_Genesis.qpf                                     | Main Quartus project file
DE2_115_Genesis.qsf                                     | Quartus project settings file
Genesis.sdc                                             | Constraints for the core
Genesis.sv                                              | Top-level module of the core
LICENSE                                                 | GPL-3.0 License
README.md                                               | This readme file
README_RUS.md                                           | Russian readme file
files.qip                                               | The core files list (Quartus IP file)


## Known issues

* Virtual Racing does not work.
* No Save RAM backup.
