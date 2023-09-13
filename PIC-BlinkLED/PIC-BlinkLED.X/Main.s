#include "xc.inc"

; CONFIG1
  CONFIG  FOSC = XT             ; Oscillator Selection bits (XT oscillator: Crystal/resonator on RA6/OSC2/CLKOUT and RA7/OSC1/CLKIN)
  CONFIG  WDTE = OFF            ; Watchdog Timer Enable bit (WDT disabled and can be enabled by SWDTEN bit of the WDTCON register)
  CONFIG  PWRTE = OFF           ; Power-up Timer Enable bit (PWRT disabled)
  CONFIG  MCLRE = ON            ; RE3/MCLR pin function select bit (RE3/MCLR pin function is MCLR)
  CONFIG  CP = OFF              ; Code Protection bit (Program memory code protection is disabled)
  CONFIG  CPD = OFF             ; Data Code Protection bit (Data memory code protection is disabled)
  CONFIG  BOREN = OFF           ; Brown Out Reset Selection bits (BOR disabled)
  CONFIG  IESO = OFF            ; Internal External Switchover bit (Internal/External Switchover mode is disabled)
  CONFIG  FCMEN = OFF           ; Fail-Safe Clock Monitor Enabled bit (Fail-Safe Clock Monitor is disabled)
  CONFIG  LVP = OFF             ; Low Voltage Programming Enable bit (RB3 pin has digital I/O, HV on MCLR must be used for programming)

; CONFIG2
  CONFIG  BOR4V = BOR40V        ; Brown-out Reset Selection bit (Brown-out Reset set to 4.0V)
  CONFIG  WRT = OFF             ; Flash Program Memory Self Write Enable bits (Write protection off)

; starting position of the program < -pRESET_VECT=0h >
psect RESET_VECT, class=CODE, delta=2
RESET_VECT:
    GOTO    setup

; memory location to go when a interrupt happens < -pINT_VECT=4h >
psect INT_VECT, class=CODE, delta=2
INT_VECT:
    
    ; save context
    MOVWF   W_TMP
    SWAPF   STATUS, W
    MOVWF   STATUS_TMP
    
    ; reset TMR0 counter
    BANKSEL TMR0
    MOVLW   0b00000000
    MOVWF   TMR0
    
    ; interruption sequence
    BANKSEL INTCON
    BTFSC   INTCON, 2		; check TMR0 flag
    CALL    blinkLED		; turn on/off LED
    
    ; reset TMR0 flag
    BANKSEL INTCON
    BCF	    INTCON, 2
    
    ; return previous context
    SWAPF   STATUS_TMP, W
    MOVWF   STATUS
    SWAPF   W_TMP, F
    SWAPF   W_TMP, W
    RETFIE

; program variables
W_TMP	    EQU 0x20
STATUS_TMP  EQU	0x21

; program setup
setup:
    
    ; PORTC configuration
    BANKSEL TRISC
    MOVLW   0b00000000		; clear TRISB vector, to put all the pin in output mode
    MOVWF   TRISC
    
    ; TMR0 configuration
    BANKSEL TMR0
    MOVLW   0b00000000		; set the initial value for TMR0 counter
    MOVWF   TMR0
    BANKSEL OPTION_REG		; use internal instruction clock for TMR0, assign prescaler to TMR0, set prescaler value
    MOVLW   0b10000111		; | /RBPU | INTEDG | T0CS | T0SE | PSA | PS2 | PS1 | PS0 |
    MOVWF   OPTION_REG
    
    ; interruptions configuration
    BANKSEL INTCON		; enable global interruptions and enagle T0IE
    MOVLW   0b10100000		; | GIE | PEIE | T0IE | INTE | RBIE | T0IF | INTF | RBIF |
    MOVWF   INTCON
    
    ; initialize PORTC
    BANKSEL PORTC
    MOVLW   0b00000001
    MOVWF   PORTC

; main program loop
main:
    
    ; VOID MAIN
    
    GOTO    main
    
; turn on/off LED subroutine
blinkLED:
    BANKSEL PORTC
    BTFSS   PORTC, 0
    GOTO    turnOnLED
    GOTO    turnOffLED
    
    ; turn on LED
    turnOnLED:
	MOVLW   0b00000001
	MOVWF   PORTC
	RETURN

    ; turn off LED
    turnOffLED:
	MOVLW   0b00000000
	MOVWF   PORTC
	RETURN

END RESET_VECT