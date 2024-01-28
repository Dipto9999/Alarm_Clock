; Lab2_MuntakimRahman_71065221.asm:
; 	a) Increments/decrements a BCD variable every second using an ISR for timer 2;
;   b) Generates a 2kHz square wave at pin P1.7 using an ISR for timer 0;
;   c) in the 'Main' Time_Loop it displays the variable incremented/decremented using the ISR for timer 2 on the LCD.
;      Also resets it to zero if the 'CLEAR' push button connected to P1.5 is pressed.
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
    ljmp Main

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
Counter_1ms:     ds 2 ; Used to determine when 1s has passed

Curr_Hours: ds 1
Display_BCD_Hours:  ds 1 ; BCD Hours Displayed on LCD
Curr_Mins: ds 1
Display_BCD_Mins:  ds 1 ; BCD Minutes Displayed on LCD
Curr_Secs: ds 1
Display_BCD_Secs:  ds 1 ; BCD Seconds Displayed on LCD

; In the 8051 we have variables that are 1-bit in size.  We can use the setb, clr, jb, and jnb
; instructions with these variables.  This is how you define a 1-bit variable:
bseg
One_Second_Flag: dbit 1 ; Set Bit In ISR After Every 1000ms
Alarm_Mode_Flag: dbit 1 ; Set Bit in ISR When Alarm Mode is Toggled
Alarm_Enabled_Flag: dbit 1 ; Set Bit in ISR When Alarm is Enabled

cseg
; Hardware Wiring for LCD
LCD_RS equ P1.3 ; Pin 12
LCD_E  equ P1.4 ; Pin 11
LCD_D4 equ P0.0 ; Pin 16
LCD_D5 equ P0.1 ; Pin 17
LCD_D6 equ P0.2 ; Pin 18
LCD_D7 equ P0.3 ; Pin 19


$NOLIST
$include(LCD_4bit.inc) ; A library of LCD related functions and utility macros
$LIST

;                     1234567890123456    <- This helps determine the location of the counter
DISPLAY_TIME_INIT:  db 'TIME 12:00:00', 0
DISPLAY_ALARM_INIT: db 'ALRM 12:00:00', 0

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
    PUSH ACC
	PUSH PSW

	; Check if Seconds Counter is Between 30 and 40
	; Generate a 2kHz Square Wave at Pin ALARM_OUT.
	MOV A, Display_BCD_Secs
	SUBB A, #0x30
	JC No_Sound

	MOV A, Display_BCD_Secs
	SUBB A, #0x40
	JNC No_Sound
Generate_Sound :
	SETB Alarm_Enabled_Flag

	CLR TR0
	MOV TH0, #HIGH(TIMER0_RELOAD)
	MOV TL0, #LOW(TIMER0_RELOAD)
	SETB TR0
	CPL ALARM_OUT ; Connect speaker the pin assigned to 'ALARM_OUT'!
	SJMP Timer0_ISR_Done
No_Sound:
	CLR Alarm_Enabled_Flag
	MOV TH0, #HIGH(TIMER0_RELOAD)
	MOV TL0, #LOW(TIMER0_RELOAD)
Timer0_ISR_Done:
	POP PSW
	POP ACC

	RETI

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
	mov Counter_1ms+0, a
	mov Counter_1ms+1, a
	; Enable the timer and interrupts
	orl EIE, #0x80 ; Enable timer 2 interrupt ET2=1
    setb TR2  ; Enable timer 2
	ret

;---------------------------------;
; ISR for timer 2                 ;
;---------------------------------;
Timer2_ISR:
	CLR TF2 ; Clear the Timer 2 Overflow Flag

	; Push Registers on Stack
	PUSH ACC
	PUSH PSW
Inc_ms_Counter:
	; Increment 16-bit ms Counter
	INC Counter_1ms+0 ; Increment Low 8-bits
	MOV A, Counter_1ms+0
	JNZ Check_1000ms

	INC Counter_1ms+1 ; Increment High 8-bits If Low 8-bits Overflow
Check_1000ms:
	; Check if 1000 ms Have Passed
	MOV A, Counter_1ms+0
	CJNE A, #LOW(1000), Timer2_ISR_Done ; Note : CJNE Changes the Carry Flag
	MOV A, Counter_1ms+1
	CJNE A, #HIGH(1000), Timer2_ISR_Done ; Note : CJNE Changes the Carry Flag
Inc_Time:
	SETB One_Second_Flag ; Let Program Know 1s Has Passed
Reset_ms_Counter:
	; Reset ms Counter. It is a 16-bit variable made with two 8-bit parts
	CLR A
	mov Counter_1ms+0, A ; Reset Low 8-bits
	JNZ Inc_Seconds
	mov Counter_1ms+1, A ; Reset High 8-bits If Low 8-bits Overflow
Inc_Seconds:
	; Increment Seconds Counter
	INC Curr_Secs
	JNB Alarm_Enabled_Flag, Inc_Seconds_Continue
BEEP:
	CPL TR0 ; Creates a Beep-Silence-Beep-Silence Sound
Inc_Seconds_Continue:
	MOV A, Curr_Secs
	DA A ; Decimal Adjust
	MOV Display_BCD_Secs, A
	CJNE A, #0x60, Timer2_ISR_Done
Reset_Seconds:
	MOV Curr_Secs, #0x00 ; Reset Seconds Counter
	MOV Display_BCD_Secs, #0x00 ; Reset Seconds Display
Inc_Minutes:
	; Increment Minutes Counter
	INC Curr_Mins
	MOV A, Curr_Mins
	DA A ; Decimal Adjust
	MOV Display_BCD_Mins, A
	CJNE A, #0x60, Timer2_ISR_Done
Reset_Minutes:
	MOV Curr_Mins, #0x00 ; Reset Minutes Counter
	MOV Display_BCD_Mins, #0x00 ; Reset Minutes Display
Inc_Hours:
	; Increment Hours Counter
	INC Curr_Hours
	MOV A, Curr_Hours
	DA A ; Decimal Adjust
	CJNE A, #0x24, Inc_Hours_Done
Reset_Hours:
	MOV Curr_Hours, #0x00 ; Reset Hours Counter
	MOV Display_BCD_Hours, #0x00 ; Reset Hours Display
Inc_Hours_Done:
	MOV Display_BCD_Hours, A
	SJMP Timer2_ISR_Done
Timer2_ISR_Done:
	; Restore Registers From Stack
	POP PSW
	POP ACC

	RETI

;---------------------------------;
; Main program. Includes hardware ;
; initialization and 'forever'    ;
; Time_Loop.                           ;
;---------------------------------;
Main:
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

	MOV Curr_Hours, #0x00
	MOV Curr_Mins, #0x00
	MOV Curr_Secs, #0x00

	MOV Display_BCD_Hours, #12
	MOV Display_BCD_Mins, #0
	MOV Display_BCD_Secs, #0

	; Initialize the LCD Time Display
	Set_Cursor(1, 1)
    Send_Constant_String(#DISPLAY_TIME_INIT)

	; Initialize the LCD Alarm Display
	Set_Cursor(2, 1)
    Send_Constant_String(#DISPLAY_ALARM_INIT)

    SETB One_Second_Flag
Time_Loop:
	SJMP Time_Loop
	SJMP Check_Set
Check_Set :
	CLR TR2 ; Stop Timer 2
	CLR A
	MOV Counter_1ms+0, A
	MOV Counter_1ms+1, A
	MOV Display_BCD_Secs, a
	SETB TR2 ; Start Timer 2

	SJMP Display_LCD_Time ; Display New Time
Display_LCD_Time:
    CLR One_Second_Flag ; Flag is Set in Timer 2 ISR and Cleared in Main Loop.

	; Display Hours
	Set_Cursor(1, 7)
	Display_BCD(Display_BCD_Hours)

	; Display Minutes
	Set_Cursor(1, 10)
	Display_BCD(Display_BCD_Mins)

	; Display Seconds
	Set_Cursor(1, 13)
	Display_BCD(Display_BCD_Secs)

    LJMP Time_Loop
END
`