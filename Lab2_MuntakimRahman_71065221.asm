; Lab2_MuntakimRahman_71065221.asm:
; 	a) Increments/decrements a BCD variable every second using an ISR for timer 2;
;   b) Generates a 2kHz square wave at pin P1.7 using an ISR for timer 0;
$NOLIST
$MODN76E003
$LIST

;  N76E003 pinout:
;                               -------
;       PWM2/IC6/T0/AIN4/P0.5 -|1    20|- P0.4/AIN5/STADC/PWM3/IC3
;               TXD/AIN3/P0.6 -|2    19|- P0.3/PWM5/IC5/AIN6
;               RXD/AIN2/P0.7 -|3    18|- P0.2/ICPCK/OCDCK/RXD_1/[SCL]
;                    RST/P2.0 -|4    17|- P0.1/PWM4/IC4/MISO
;        INT0/OSCIN/AIN1/P3.0 -|5    16|- P0.0/PWM3/IC3/MOSI/T1
;              INT1/AIN0/P1.7 -|6    15|- P1.0/PWM2/IC2/SPCLK
;                         GND -|7    14|- P1.1/PWM1/IC1/AIN7/CLO
;[SDA]/TXD_1/ICPDA/OCDDA/P1.6 -|8    13|- P1.2/PWM0/IC0
;                         VDD -|9    12|- P1.3/SCL/[STADC]
;            PWM5/IC7/SS/P1.5 -|10   11|- P1.4/SDA/FB/PWM1
;                               -------
;

CLK           EQU 16600000 ; Microcontroller system frequency in Hz
TIMER0_RATE   EQU 4096     ; 2048Hz squarewave (peak amplitude of CEM-1203 speaker)
TIMER0_RELOAD EQU ((65536-(CLK/TIMER0_RATE)))

TIMER2_RATE   EQU 1000     ; 1000Hz, for a timer tick of 1ms
TIMER2_RELOAD EQU ((65536-(CLK/TIMER2_RATE)))

TOGGLE_BUTTON  equ P0.4 ; Pin 20
SET_BUTTON     equ P0.5 ; Pin 1

HOURS_BUTTON   equ P3.0 ; Pin 5
MINUTES_BUTTON equ P1.6 ; Pin 8
SECONDS_BUTTON equ P1.5 ; Pin 10

ALARM_OUT      equ P1.7 ; Pin 6

; Reset vector
org 0x0000
    ljmp main

; External interrupt 0 vector (not used in this code)
org 0x0003
	reti

; Timer/Counter 0 overflow interrupt vector
org 0x000B
	ljmp Timer0_ISR

; External interrupt 1 vector (not used in this code)
org 0x0013
	reti

; Timer/Counter 1 overflow interrupt vector (not used in this code)
org 0x001B
	reti

; Serial port receive/transmit interrupt vector (not used in this code)
org 0x0023
	reti

; Timer/Counter 2 overflow interrupt vector
org 0x002B
	ljmp Timer2_ISR

; In the 8051 we can define direct access variables starting at location 0x30 up to location 0x7F
dseg at 0x30
Count1ms:     ds 2 ; Used to determine when half second has passed

BCD_Hours:  ds 1
BCD_Minutes:  ds 1
BCD_Seconds:  ds 1

BCD_Alarm_Hours:  ds 1
BCD_Alarm_Minutes:  ds 1

; In the 8051 we have variables that are 1-bit in size.  We can use the setb, clr, jb, and jnb
; instructions with these variables.  This is how you define a 1-bit variable:
bseg
One_Second_Flag: dbit 1 ; Set Bit In ISR After Every 1000ms

Alarm_En_Flag: dbit 1
Alarm_Activate_Flag: dbit 1

Alarm_Toggle_Flag: dbit 1
Time_PM_Flag: dbit 1 ; Set Bit When Time is in PM
Alarm_PM_Flag: dbit 1 ; Set Bit When Alarm is in PM

cseg
; These 'equ' must match the hardware wiring
LCD_RS equ P1.3
;LCD_RW equ PX.X ; Not used in this code, connect the pin to GND
LCD_E  equ P1.4
LCD_D4 equ P0.0
LCD_D5 equ P0.1
LCD_D6 equ P0.2
LCD_D7 equ P0.3

$NOLIST
$include(LCD_4bit.inc) ; A library of LCD related functions and utility macros
$LIST

Time_Msg:  db 'Time xx:xx:xxxx', 0, 0, 0, 0
Alarm_Msg:  db 'Alarm xx:xxxx', 0, 0, 0
AM_Msg: db 'AM', 0
PM_Msg: db 'PM', 0

;---------------------------------;
; Routine to initialize the ISR   ;
; for timer 0                     ;
;---------------------------------;
Timer0_Init:
	orl CKCON, #0b00001000 ; Input for timer 0 is sysclk/1
	mov a, TMOD
	anl a, #0xf0 ; 11110000 Clear the bits for timer 0
	orl a, #0x01 ; 00000001 Configure timer 0 as 16-timer
	mov TMOD, a
	mov TH0, #high(TIMER0_RELOAD)
	mov TL0, #low(TIMER0_RELOAD)
	; Enable the timer and interrupts
    setb ET0  ; Enable timer 0 interrupt
    setb TR0  ; Start timer 0
	ret

;---------------------------------;
; ISR for timer 0.  Set to execute;
; every 1/4096Hz to generate a    ;
; 2048 Hz wave at pin ALARM_OUT   ;
;---------------------------------;
Timer0_ISR:
	; Timer 0 Doesn't Have 16-Bit Auto-Reload.
    push acc
	push psw

	jnb Alarm_Activate_Flag, No_Sound
Generate_Sound:
	clr TR0
	mov TH0, #high(TIMER0_RELOAD)
	mov TL0, #low(TIMER0_RELOAD)
	setb TR0
	cpl ALARM_OUT ; Connect speaker the pin assigned to 'ALARM_OUT'!
	sjmp Timer0_ISR_Done
No_Sound:
	mov TH0, #high(TIMER0_RELOAD)
	mov TL0, #low(TIMER0_RELOAD)
Timer0_ISR_Done:
	pop psw
	pop acc

	reti

;---------------------------------;
; Routine to initialize the ISR   ;
; for timer 2                     ;
;---------------------------------;
Timer2_Init:
	mov T2CON, #0 ; Stop timer/counter.  Autoreload mode.
	mov TH2, #high(TIMER2_RELOAD)
	mov TL2, #low(TIMER2_RELOAD)
	; Set the reload value
	orl T2MOD, #0x80 ; Enable timer 2 autoreload
	mov RCMP2H, #high(TIMER2_RELOAD)
	mov RCMP2L, #low(TIMER2_RELOAD)
	; Init One millisecond interrupt counter.  It is a 16-bit variable made with two 8-bit parts
	clr a
	mov Count1ms+0, a
	mov Count1ms+1, a
	; Enable the timer and interrupts
	orl EIE, #0x80 ; Enable timer 2 interrupt ET2=1
    setb TR2  ; Enable timer 2
	ret

;---------------------------------;
; ISR for timer 2                 ;
;---------------------------------;
Timer2_ISR:
	clr TF2  ; Timer 2 doesn't clear TF2 automatically. Do it in the ISR.  It is bit addressable.
	cpl P0.4 ; To check the interrupt rate with oscilloscope. It must be precisely a 1 ms pulse.

	; The two registers used in the ISR must be saved in the stack
	push acc
	push psw
	push ar1

	; Increment the 16-bit one mili second counter
	inc Count1ms+0    ; Increment the low 8-bits first
	mov a, Count1ms+0 ; If the low 8-bits overflow, then increment high 8-bits
	jnz Inc_BCD
	inc Count1ms+1

Inc_BCD:
	; Check if half second has passed
	mov a, Count1ms+0
	cjne a, #low(1000), Timer2_ISR_Done ; Warning: this instruction changes the carry flag!
	mov a, Count1ms+1
	cjne a, #high(1000), Timer2_ISR_Done

	; 1000 milliseconds have passed.  Set a flag so the main program knows
	setb One_Second_Flag ; Let the main program know half second had passed
Check_Alarm:
	mov a, BCD_Hours
	cjne a, BCD_Alarm_Hours, No_Alarm

	mov a, BCD_Minutes
	cjne a, BCD_Alarm_Minutes, No_Alarm

	; Check AM/PM Flag
	clr a
	mov b, a ; At this point A and B are zero
	mov c, Time_PM_Flag
	mov b.0, c
	mov c, Alarm_PM_Flag
	mov acc.0, c
	cjne a, b, No_Alarm
BEEP:
	setb Alarm_Activate_Flag
	cpl TR0 ; Enable/disable timer/counter 0. This line creates a beep-silence-beep-silence sound.
	sjmp Continue_ISR
No_Alarm:
	clr Alarm_Activate_Flag
Continue_ISR:
	; Reset to zero the milli-BCD_Seconds counter, it is a 16-bit variable
	clr a
	mov Count1ms+0, a
	mov Count1ms+1, a
Inc_Second:
	mov a, BCD_Seconds
	add a, #1
	da a
	mov BCD_Seconds, a
	cjne a, #0x60, Timer2_ISR_Done
Inc_Minute:
	mov BCD_Seconds, #0x00

	mov a, BCD_Minutes
	add a, #1
	da a
	mov BCD_Minutes, a
	cjne a, #0x60, Timer2_ISR_Done
Inc_Hour:
	mov BCD_Minutes, #0x00

	mov a, BCD_Hours
	add a, #1
	da a
	mov BCD_Hours, a
	cjne a, #0x12, Timer2_ISR_Done
Toggle_AM_PM:
	mov BCD_Hours, #0x12
	cpl Time_PM_Flag
Timer2_ISR_Done:
	pop ar1
	pop psw
	pop acc
	reti

;---------------------------------;
; Main program. Includes hardware ;
; initialization and 'forever'    ;
; Toggle_Mode_Check.                           ;
;---------------------------------;
main:
	; Initialization
    mov SP, #0x7F
    mov P0M1, #0x00
    mov P0M2, #0x00
    mov P1M1, #0x00
    mov P1M2, #0x00
    mov P3M2, #0x00
    mov P3M2, #0x00

    lcall Timer0_Init
    lcall Timer2_Init
    setb EA   ; Enable Global interrupts
    lcall LCD_4BIT
    ; For convenience a few handy macros are included in 'LCD_4bit.inc':
	Set_Cursor(1, 1)
    Send_Constant_String(#Time_Msg)
	Set_Cursor(2, 1)
    Send_Constant_String(#Alarm_Msg)

    setb One_Second_Flag
	clr Alarm_En_Flag
	clr Alarm_Activate_Flag
	clr Alarm_Toggle_Flag
	clr Time_PM_Flag
	clr Alarm_PM_Flag

	mov a, #0x11
	da a
	mov BCD_Hours, a

	mov a, #0x59
	da a
	mov BCD_Minutes, a

	mov a, #0x50
	da a
	mov BCD_Seconds, a

	mov a, #0x12
	da a
	mov BCD_Alarm_Hours, a

	mov a, #0x00
	da a
	mov BCD_Alarm_Minutes, a

	; After initialization the program stays in this 'forever' Toggle_Mode_Check
Toggle_Mode_Check:
	; Wait and See Method.
	jb TOGGLE_BUTTON, Current_Mode  ; Skip if Toggle Button is Not Pressed
	Wait_Milli_Seconds(#50)
	jb TOGGLE_BUTTON, Current_Mode ; Skip if Toggle Button is Not Pressed
	Wait_Milli_Seconds(#250)
	jnb TOGGLE_BUTTON, $ ; Jump to Same Instruction Once Button is Released.
Toggle_Mode:
	cpl Alarm_Toggle_Flag
Current_Mode:
	jnb One_Second_Flag, Toggle_Mode_Check
	jnb Alarm_Toggle_Flag, User_Inc_Time
User_Inc_Alarm:
	sjmp User_Inc_Alarm_Hours
User_Inc_Alarm_Hours:
	jb HOURS_BUTTON, Check_Alarm_Minutes
	Wait_Milli_Seconds(#50)
	jb HOURS_BUTTON, Check_Alarm_Minutes
	Wait_Milli_Seconds(#250)
	jnb HOURS_BUTTON, $

	mov a, BCD_Alarm_Hours
	add a, #1
	da a
	mov BCD_Alarm_Hours, a
	cjne a, #0x12, Update_LCD_Display
	mov BCD_Alarm_Hours, #0x00
	ljmp Update_LCD_Display ; Display the New Time
Check_Alarm_Minutes:
	jb MINUTES_BUTTON, Update_LCD_Display
	Wait_Milli_Seconds(#50)
	jb MINUTES_BUTTON, Update_LCD_Display
	Wait_Milli_Seconds(#250)
	jnb MINUTES_BUTTON, $

	mov a, BCD_Alarm_Minutes
	add a, #1
	da a
	mov BCD_Alarm_Minutes, a
	cjne a, #0x60, Update_LCD_Display
	mov BCD_Alarm_Minutes, #0x00
	ljmp Update_LCD_Display ; Display the New Time

User_Inc_Time:
	sjmp User_Inc_Hours
User_Inc_Hours:
	sjmp User_Inc_Seconds
User_Inc_Seconds:
	sjmp Update_LCD_Display

Update_LCD_Display:
    clr One_Second_Flag

	Set_Cursor(1, 6)
	Display_BCD(BCD_Hours)
	Set_Cursor(1, 9)
	Display_BCD(BCD_Minutes)
	Set_Cursor(1, 12)
	Display_BCD(BCD_Seconds)

	Set_Cursor(2, 7)
	Display_BCD(BCD_Alarm_Hours)
	Set_Cursor(2, 10)
	Display_BCD(BCD_Alarm_Minutes)
Display_Time_AMPM:
	jb Time_PM_Flag, Display_Time_PM
Display_Time_AM:
	Set_Cursor(1, 14)
	Send_Constant_String(#AM_MSG)
	ljmp Display_Alarm_AMPM
Display_Time_PM:
	Set_Cursor(1, 14)
	Send_Constant_String(#PM_MSG)
	ljmp Display_Alarm_AMPM
Display_Alarm_AMPM:
	jb Alarm_PM_Flag, Display_Alarm_PM
Display_Alarm_AM:
	Set_Cursor(2, 12)
	Send_Constant_String(#AM_MSG)
    ljmp Toggle_Mode_Check
Display_Alarm_PM:
	Set_Cursor(2, 12)
	Send_Constant_String(#PM_MSG)
    ljmp Toggle_Mode_Check
END
`