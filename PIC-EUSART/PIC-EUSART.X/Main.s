#include "xc.inc"

; CONFIG1
  CONFIG  FOSC = INTRC_NOCLKOUT ; Oscillator Selection bits (INTOSCIO oscillator: I/O function on RA6/OSC2/CLKOUT pin, I/O function on RA7/OSC1/CLKIN)
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
    
    ; EUSART receive interruption
    BANKSEL PIR1
    BTFSC   PIR1, 5		; check RCIF bit
    CALL    EUSARTreceiveISR
    
    ; return previous context
    SWAPF   STATUS_TMP, W
    MOVWF   STATUS
    SWAPF   W_TMP, F
    SWAPF   W_TMP, W
    RETFIE

; interruptions context variables
W_TMP		EQU 0x20	; temporary W
STATUS_TMP	EQU 0x21	; temporary STATUS
VAR_TMP		EQU 0x22	; temporary general purpose register

; EUSART
EUSARTreceived	EQU 0x28	; data received from EUSART

; variables
VAL_0		EQU 0x30
VAL_1		EQU 0x31

; table to convert a W value from hexadecimal to ASCII
hexToASCIItable:
    ADDWF   $, F
    RETLW   '0'			; ASCII 0x30
    RETLW   '1'			; ASCII 0x31
    RETLW   '2'			; ASCII 0x32
    RETLW   '3'			; ASCII 0x33
    RETLW   '4'			; ASCII 0x34
    RETLW   '5'			; ASCII 0x35
    RETLW   '6'			; ASCII 0x36
    RETLW   '7'			; ASCII 0x37
    RETLW   '8'			; ASCII 0x38
    RETLW   '9'			; ASCII 0x39
    RETLW   'A'			; ASCII 0x41
    RETLW   'B'			; ASCII 0x42
    RETLW   'C'			; ASCII 0x43
    RETLW   'D'			; ASCII 0x44
    RETLW   'E'			; ASCII 0x45
    RETLW   'F'			; ASCII 0x46

; program setup
setup:
    
    ; EUSART configuration
    BANKSEL TXSTA
    MOVLW   0b00100110		; | CSRC | TX9 | TXEN | SYNC | SENDB | BRGH | TRMT | TX9D |
    MOVWF   TXSTA		; enables transmitter, set asynchronous mode and high speed
    BANKSEL RCSTA
    MOVLW   0b10010000		; | SPEN | RX9 | SREN | CREN | ADDEN | FERR | OERR | RX9D |
    MOVWF   RCSTA		; enables serial port, enables receiver
    BANKSEL SPBRG
    MOVLW   0x19		; set the baud rate generator
    MOVWF   SPBRG
    BANKSEL SPBRGH		; clear SPBRGH
    CLRF    SPBRGH
    
    ; interruptions configuration
    MOVLW   0b01000000		; | GIE | PEIE | T0IE | INTE | RBIE | T0IF | INTF | RBIF |
    MOVWF   INTCON		; enables  interruptions in PEIE
    BANKSEL PIE1
    MOVLW   0b00100000		; | xx | ADIE | RCIE | TXIE | SSPIE | CCP1IE | TMR2IE | TMR1IE |
    MOVWF   PIE1		; enables interruptions in EUSART receive
    
    ; interruptions initialization
    BSF	    INTCON, 7		; enable global interruptions
    
    ; select memory bank 0 <00>
    BCF	    STATUS, 5		; clear RP0 bit
    BCF	    STATUS, 6		; clear RP1 bit
    
    ; variables initialization
    MOVLW   0x24
    MOVWF   VAL_0
    MOVLW   0x59
    MOVWF   VAL_1

; main program loop
main:
    
    ; ASCII new line
    MOVLW   0x0D
    CALL    EUSARTtransmit
    MOVLW   0x0A
    CALL    EUSARTtransmit
    
    ; EUSART transmit characters
    MOVF    VAL_0, W
    CALL    hexToASCIIhighConv
    CALL    EUSARTtransmit
    MOVF    VAL_0, W
    CALL    hexToASCIIlowConv
    CALL    EUSARTtransmit
    MOVF    VAL_1, W
    CALL    hexToASCIIhighConv
    CALL    EUSARTtransmit
    MOVF    VAL_1, W
    CALL    hexToASCIIlowConv
    CALL    EUSARTtransmit
    
    GOTO    main
    
; EUSART transmit pre-loaded value in W
EUSARTtransmit:
    BCF	    INTCON, 7		; clear GIE bit to prevent interruptions
    BANKSEL TXREG
    MOVWF   TXREG		; load the W data into TXREG
    BANKSEL TXSTA
    BTFSS   TXSTA, 1		; check if the data has been sent
    GOTO    $-1			; loop until the data has been sent
    
    ; end of EUSARTtransmit
    BSF	    INTCON, 7		; set GIE bit to resume interruptions
    BCF	    STATUS, 5		; clear RP0 bit
    BCF	    STATUS, 6		; clear RP1 bit
    RETURN
    
; EUSART receive
EUSARTreceiveISR:
    BANKSEL RCREG
    MOVF    RCREG, W
    MOVWF   EUSARTreceived	; load the received data into EUSARTreceived
    
    ; end of EUSARTreceiveISR
    RETURN
    
; convert the low nibble of W from hexadecimal to ASCII
hexToASCIIlowConv:
    ANDLW   0b00001111
    CALL    hexToASCIItable
    RETURN
    
; convert the high nibble of W from hexadecimal to ASCII
hexToASCIIhighConv:
    MOVWF   VAR_TMP
    SWAPF   VAR_TMP, W
    ANDLW   0b00001111
    CALL    hexToASCIItable
    RETURN
    
END RESET_VECT