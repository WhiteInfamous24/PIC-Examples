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
    
    ; interruption implementation
    BANKSEL INTCON
    BTFSC   INTCON, 1		; check if the interruption was the RB0 pin
    CALL    incCnter		; increment counter
    
    ; clear INTF flag
    BANKSEL INTCON
    BCF	    INTCON, 1		; clear INTF flag
    
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
    MOVLW   0b00000000		; set the PORTC as output
    MOVWF   TRISC
    
    ; PORTB configuration
    BANKSEL TRISB
    MOVLW   0b00000001		; set RB0 pin as input
    MOVWF   TRISB
    BANKSEL ANSELH
    CLRF    ANSELH		; set PORTB as digital
    BANKSEL OPTION_REG
    BCF	    OPTION_REG, 7	; enable global pull-ups
    BANKSEL WPUB
    MOVLW   0b00000001		; enable RB0 pull-up
    MOVWF   WPUB
    
    ; interruption configuration
    BANKSEL INTCON		; enable global interruptions and enable interruptions in PORTB
    MOVLW   0b10010000		; | GIE | PEIE | T0IE | INTE | RBIE | T0IF | INTF | RBIF |
    MOVWF   INTCON
    BANKSEL IOCB		; set PORTB pins that will interrupt
    MOVLW   0b00000001		; set RB0 as interruption pin
    MOVWF   IOCB
    
    ; initialize PORTC
    BANKSEL PORTC
    MOVLW   0b00000000
    MOVWF   PORTC

; main program loop
main:
    
    ; VOID MAIN
    
    GOTO    main
    
; increment PORTC value subroutine
incCnter:
    BANKSEL PORTC
    INCF    PORTC, F
    RETURN

END RESET_VECT