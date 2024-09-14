# Alarm Clock

## Contents

* [Overview](#Overview)
* [Hardware](#Hardware)
* [Firmware](#Firmware)
    * [Interrupts](#Interrupts)
    * [Flags](#Flags)
    * [Compile & Flash](#Compile-&-Flash)
* [Demonstration](#Demonstration)
* [Credit](#Credit)

## Overview

I built a prototype circuit for a simple alarm clock. This was designed such that the user starts by setting the time and alarm with pushbuttons. The time would then start to increment as on an everyday clock. When enabled, a speaker circuit would sound the alarm (until it's disabled or *1 min* has elapsed).

Once the clock is configured, the alarm and time display mode could be adjusted with the original pushbuttons.

## Hardware

This was built with the following electronic kit equipment:

* **N76E003** microcontroller to power and control the circuit.
* **CEM-1203** magnetic buzzer transducter, **FQU13N06LS** MOSFET and **1N4148** diode for the speaker.
* **CM-S01602DTR/M LCD** for the time/alarm display.
* Pushbuttons to change the program settings.

## Firmware

This was implemented in **8051 ASM** for the **N76E003** microcontroller. The program consisted of a `main` loop to receive user input (i.e. via pushbuttons) and update the **LCD** display. **Interrupt Service Routines (ISR)** were used to implement the underlying timer and alarm functionality.

### Interrupts

`Timer2_ISR` updated the time and checked if the alarm should be enabled. It asynchronously wrote to the `BCD_Time_` and `BCD_Alarm_` *1 byte* defined spaces to share data with the `Update_LCD_Display` function in the `main` program.

`Timer0_ISR` generated the square wave for the speaker.

<i>Note that **LCD** functionality was required to be synchronous due to the high latency and lower priority of operation.</i>

### Flags

Flags were used to determine program functionality across **ISRs** and the `main` program. These were designed to be similar to global variables in a higher level programming language.

These included:
* When the time was being initialized and the **LCD** should not be updated.
* When *1 s* had elapsed and should be updated on the **LCD**.
* Whether the **LCD** display should be in *AM/PM* or *military time* mode.
* When the alarm should be enabled for generating the square wave on the output speaker.

Based on their purpose, these were either set by the `main` program or the `Timer2_ISR`.

### Compile & Flash

The build tasks in the [`.vscode`](Firmware/.vscode/tasks.json) file were set up to run :
* the `a51.exe` executable to compile the [`Alarm_Clock.asm`](Firmware/Alarm_Clock.asm) file
* the `ISPN76E003.exe` executable to flash the program onto the **N76E003** microcontroller

## Demonstration

I have uploaded the Demo on <a href="https://youtu.be/p5Kv5WFh1MI?si=RrNQxbT8ROXKCoxP" target="_blank">Youtube</a>.

https://github.com/user-attachments/assets/2aec9b11-f9bf-4617-bc0e-256b9d96d5b6

## Credit

This was completed as part of the <b>ELEC 291 - Design Studio</b> project course in the <b>The University of British Columbia Electrical and Computer Engineering</b> undergraduate program. I received tremendous support and guidance from Dr. Jesus Calvino-Fraga.
