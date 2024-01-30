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

SET_BUTTON  equ P1.1 ; Pin 14

DECREMENT_BUTTON     equ P0.5 ; Pin 1
HOURS_BUTTON         equ P3.0 ; Pin 5
MINUTES_BUTTON       equ P1.6 ; Pin 8
SECONDS_BUTTON       equ P1.5 ; Pin 10

ALARM_OUT            equ P1.7 ; Pin 6

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

BCD_Time_Hours:  ds 1
BCD_Time_Minutes:  ds 1
BCD_Time_Seconds:  ds 1

BCD_Alarm_Hours:  ds 1
BCD_Alarm_Minutes:  ds 1

; In the 8051 we have variables that are 1-bit in size.  We can use the setb, clr, jb, and jnb
; instructions with these variables.  This is how you define a 1-bit variable:
bseg
One_Second_Flag: dbit 1 ; Set Bit In ISR After Every 1000ms

Alarm_En_Flag: dbit 1
Alarm_Activate_Flag: dbit 1

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

TIME_MSG:  db 'TIME xx:xx:xxxx', 0, 0, 0, 0
ALARM_MSG:  db 'ALARM xx:xxxx', 0
ALARM_UPDATE_MSG:  db 'ALARM', 0

AM_MSG: db 'AM', 0
PM_MSG: db 'PM', 0

BLANK_DISPLAY: db '                ', 0

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

	jnb Alarm_En_Flag, No_Sound
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
	jnb Alarm_En_Flag, No_Alarm

	; Check if Time Hours Equals Alarm Hours
	mov a, BCD_Time_Hours
	cjne a, BCD_Alarm_Hours, No_Alarm

	; Check if Time Minutes Equals Alarm Minutes
	mov a, BCD_Time_Minutes
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
	cpl TR0 ; Create Beep-Silence-Beep-Silence Sounds
	sjmp Continue_ISR
No_Alarm:
	clr Alarm_Activate_Flag
Continue_ISR:
	; Reset to zero the milli-BCD_Time_Seconds counter, it is a 16-bit variable
	clr a
	mov Count1ms+0, a
	mov Count1ms+1, a
	lcall Inc_Time_Seconds
Timer2_ISR_Done:
	pop psw
	pop acc
	reti

;---------------------------------;
; Main program. Includes hardware ;
; initialization and 'forever'    ;
; Check_Buttons.                           ;
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
    setb EA   ; Enable Global Interrupts
    lcall LCD_4BIT

    setb One_Second_Flag
Init_Display:
	lcall Init_Time
Init_Alarm:
	setb Alarm_En_Flag
	clr Alarm_Activate_Flag

	Set_Cursor(2, 1)
    Send_Constant_String(#ALARM_MSG)

	; Starting Alarm is 01:00 PM
	setb Alarm_PM_Flag
	mov a, #0x01
	da a
	mov BCD_Alarm_Hours, a

	mov a, #0x00
	da a
	mov BCD_Alarm_Minutes, a

	ljmp Update_LCD_Display
	; After initialization the program stays in this 'forever' Check_Buttons
Check_Buttons:
	sjmp Check_Inc_Alarm
Check_Inc_Alarm:
	sjmp Check_Inc_Alarm_Set
Check_Inc_Alarm_Set:
	jb SET_BUTTON, Check_Inc_Alarm_Minutes
	Wait_Milli_Seconds(#50)
	jb SET_BUTTON, Check_Inc_Alarm_Minutes
	jnb SET_BUTTON, $ ; Wait for Rising Edge
	cpl Alarm_En_Flag
Check_Inc_Alarm_Minutes:
	jb MINUTES_BUTTON, Check_Inc_Alarm_Hours
	Wait_Milli_Seconds(#50)
	jb MINUTES_BUTTON, Check_Inc_Alarm_Hours
	jnb MINUTES_BUTTON, $ ; Wait for Rising Edge
	lcall Inc_Alarm_Minutes ; Increment Alarm Minutes
Check_Inc_Alarm_Hours:
	jb HOURS_BUTTON, Update_LCD_Display
	Wait_Milli_Seconds(#50)
	jb HOURS_BUTTON, Update_LCD_Display
	jnb HOURS_BUTTON, $ ; Wait for Rising Edge
	lcall Inc_Alarm_Hours ; Increment Alarm Hours
	ljmp Update_LCD_Display

;--------------------;
; Update LCD Display ;
;--------------------;
Update_LCD_Display:
    clr One_Second_Flag
	lcall Update_Time_Display
	lcall Update_Alarm_Display
	ljmp Check_Buttons

Update_Time_Display:
	; Display Time
	Set_Cursor(1, 6)
	Display_BCD(BCD_Time_Hours)
	Set_Cursor(1, 9)
	Display_BCD(BCD_Time_Minutes)
	Set_Cursor(1, 12)
	Display_BCD(BCD_Time_Seconds)

	jb Time_PM_Flag, Update_Time_PM
Update_Time_AM:
	Set_Cursor(1, 14)
	Send_Constant_String(#AM_MSG)
	ret
Update_Time_PM:
	Set_Cursor(1, 14)
	Send_Constant_String(#PM_MSG)
	ret

Update_Alarm_Display:
	jb Alarm_En_Flag, Update_Alarm_En_On
	ljmp Update_Alarm_En_Off
Update_Alarm_En_On:
	; Display Alarm
	Set_Cursor(2, 1)
	Send_Constant_String(#ALARM_UPDATE_MSG)
	Set_Cursor(2, 7)
	Display_BCD(BCD_Alarm_Hours)
	Set_Cursor(2, 10)
	Display_BCD(BCD_Alarm_Minutes)

	jb Alarm_PM_Flag, Update_Alarm_PM
Update_Alarm_AM:
	Set_Cursor(2, 12)
	Send_Constant_String(#AM_MSG)
    ret
Update_Alarm_PM:
	Set_Cursor(2, 12)
	Send_Constant_String(#PM_MSG)
    ret
Update_Alarm_En_Off:
	Set_Cursor(2, 1)
	Send_Constant_String(#BLANK_DISPLAY)
	ret

Init_Time:
	clr Time_PM_Flag
	clr TR2 ; Stop Timer 2

	; Starting Display is 1:00:00 AM
	mov a, #0x12
	mov BCD_Time_Hours, a

	mov a, #0x00
	mov BCD_Time_Minutes, a

	mov a, #0x00
	mov BCD_Time_Seconds, a

	Set_Cursor(1, 1)
    Send_Constant_String(#TIME_MSG)
Check_Set_Time:
	jb SET_BUTTON, Init_Time_Display
	; setb TR2 ; Start Timer 2
	Wait_Milli_Seconds(#50)
	; clr TR2 ; Stop Timer 2
	jb SET_BUTTON, Init_Time_Display
	jnb SET_BUTTON, $ ; Wait for Rising Edge
	ljmp Init_Time_End
Init_Time_Display:
	lcall Update_Time_Display
Init_Time_Seconds:
	jb SECONDS_BUTTON, Init_Time_Minutes
	Wait_Milli_Seconds(#50)
	jb SECONDS_BUTTON, Init_Time_Minutes
	jnb SECONDS_BUTTON, $

	lcall Inc_Time_Seconds
Init_Time_Minutes:
	jb MINUTES_BUTTON, Init_Time_Hours
	Wait_Milli_Seconds(#50)
	jb MINUTES_BUTTON, Init_Time_Hours
	jnb MINUTES_BUTTON, $

	lcall Inc_Time_Minutes
Init_Time_Hours:
	jb HOURS_BUTTON, Init_Time_Loop
	Wait_Milli_Seconds(#50)
	jb HOURS_BUTTON, Init_Time_Loop
	jnb HOURS_BUTTON, $

	lcall Inc_Time_Hours
Init_Time_Loop:
	ljmp Check_Set_Time
Init_Time_End:
	setb TR2 ; Set Timer 2
	ret

;-------------------------------;
; Increment Time on LCD Display ;
;-------------------------------;
Inc_Time_Hours:
	mov a, BCD_Time_Hours
	add a, #1
	da a
	mov BCD_Time_Hours, a
	subb a, #0x12
	jc Inc_Time_Hours_Done
	jnz Offset_Time_Hours
Toggle_Time_AMPM:
	mov BCD_Time_Hours, #0x12
	cpl Time_PM_Flag
	ljmp Inc_Time_Hours_Done
Offset_Time_Hours:
	mov a, BCD_Time_Hours
	subb a, #0x12
	da a
	mov BCD_Time_Hours, a
Inc_Time_Hours_Done:
	ret

Inc_Time_Minutes:
	mov a, BCD_Time_Minutes
	add a, #1
	da a
	mov BCD_Time_Minutes, a
	cjne a, #0x60, Inc_Time_Minutes_Done
	mov BCD_Time_Minutes, #0x00
	lcall Inc_Time_Hours
Inc_Time_Minutes_Done:
	ret

Inc_Time_Seconds:
	mov a, BCD_Time_Seconds
	add a, #1
	da a
	mov BCD_Time_Seconds, a
	cjne a, #0x60, Inc_Time_Seconds_Done
	mov BCD_Time_Seconds, #0x00
	lcall Inc_Time_Minutes
Inc_Time_Seconds_Done:
	ret

Inc_Alarm_Hours:
	mov a, BCD_Alarm_Hours
	add a, #1
	da a
	mov BCD_Alarm_Hours, a
	subb a, #0x12
	jc Inc_Alarm_Hours_Done
	jnz Offset_Alarm_Hours
Toggle_Alarm_AMPM:
	mov BCD_Alarm_Hours, #0x12
	cpl Alarm_PM_Flag
	ljmp Inc_Alarm_Hours_Done
Offset_Alarm_Hours:
	mov a, BCD_Alarm_Hours
	subb a, #0x12
	da a
	mov BCD_Alarm_Hours, a
Inc_Alarm_Hours_Done:
	ret

Inc_Alarm_Minutes:
	mov a, BCD_Alarm_Minutes
	add a, #1
	da a
	mov BCD_Alarm_Minutes, a
	cjne a, #0x60, Inc_Alarm_Minutes_Done
	mov BCD_Alarm_Minutes, #0x00
	lcall Inc_Alarm_Hours
Inc_Alarm_Minutes_Done:
	ret

END
`