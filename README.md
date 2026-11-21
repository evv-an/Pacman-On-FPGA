# Pacman-On-FPGA

A Pac-Man-style game written in Verilog for the DE1-SoC (Cyclone V) FPGA, played on a VGA monitor. Final project for ECE 287 (Digital Systems Design), Miami University, Fall 2026.

## Ghost pathfinding

Each ghost runs its own copy of `ghost_controller.v`. At the center of every tile, the ghost looks at each direction that isn't a wall and isn't straight back the way it came. It takes the one that brings it closest to its target tile (by squared distance). Ties go up, left, down, right. Each ghost picks its target differently:

- **Blinky** chases Pac-Man's tile directly.
- **Pinky** aims 4 tiles ahead of Pac-Man.
- **Inky** doubles the vector from Blinky to Pac-Man, so he flanks.
- **Clyde** chases from more than 8 tiles away, then retreats to his corner up close.
- **Frightened** ghosts all flee to corners instead.

## Game logic

- **Collision:** before each step, the two corner tiles ahead of a character are checked against the maze ROM. A turn you hold against a wall happens as soon as the path opens.
- **Pellets and score:** each tile has one bit that remembers whether its pellet was eaten. Pellets are worth 10, power pellets 50, and ghosts eaten in a row 200/400/800/1600.
- **Power pellets:** ghosts are frightened for 6 seconds and flash for the last 1.5. An eaten ghost goes back to the ghost house.
- **Ghost release:** ghosts leave the ghost house one at a time, based on pellets eaten and a timer.
- **Lives and levels:** you start with 3 lives (hearts on screen) and freeze for 2 seconds on death. Level 2 has its own maze and gives an extra life. The game ends on a win/lose screen.
- **Easter eggs:** there's one hidden on each level. Eat all four ghosts on a single power pellet to find it.
- **Rendering:** the maze is drawn into a 160×120 frame buffer, timed to VGA vsync. The characters are drawn on top at the full 640×480.

## Controls

SW9 turns the game on and resets it. KEY0/KEY3/KEY1/KEY2 move up/down/left/right, or use the joystick. SW0 skips to level 2. The score shows on HEX4–HEX0.

**Joystick:** an analog thumbstick is read by an Arduino running [`joystick_to_fpga.ino`](arduino/joystick_to_fpga/joystick_to_fpga.ino), which turns it into four active-low direction signals. It calibrates the stick's center at startup and uses a deadzone with hysteresis so only one direction is ever active.

| Joystick | Arduino | FPGA |
|---|---|---|
| VRx / VRy | A0 / A1 | |
| | pins 4 / 5 / 6 / 7 (up / down / left / right) | GPIO_0[0] / [1] / [2] / [3] |
| GND | GND | GND |

The DE1-SoC's GPIO pins are 3.3 V, so a 5 V Arduino's outputs need level shifting before they reach the board.

## Build

Open `vga_driver_to_frame_buf.qpf` in Quartus Prime Lite 23.1, compile, and program the `.sof` onto the board. Every version is tagged on the [Releases](../../releases) page, and the latest release includes a ready-to-program `.sof`.

## Team

Evan Sabol and Ash Carr

## Acknowledgments

- The original VGA and frame-buffer code is course starter code by Dr. Peter Jamieson.
- Google Gemini helped with debugging and with repetitive work, like instantiating modules and repeating logic we'd already written for each ghost and sprite. The Arduino joystick code was generated with Google Gemini. Claude (Anthropic) helped write this README.
- This is a fan project, not affiliated with Bandai Namco or Nintendo.
