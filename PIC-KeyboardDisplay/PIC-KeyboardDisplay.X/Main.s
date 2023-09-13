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
    
    ; keyboard interruption
    BTFSC   INTCON, 0		; check RBIF bit
    CALL    keyboardISR
    
    ; TMR0 interruption
    BTFSC   INTCON, 2		; check T0IF bit
    CALL    TMR0ISR
    
    ; return previous context
    SWAPF   STATUS_TMP, W
    MOVWF   STATUS
    SWAPF   W_TMP, F
    SWAPF   W_TMP, W
    RETFIE

; program variables
W_TMP	    EQU 0x20
STATUS_TMP  EQU	0x21

; timer 0
TMR0_CNTR   EQU	0x28

; keyboard
KYBRD_BTN   EQU	0x30
KYBRD_FND_F EQU	0x31

; program setup
setup:
    
    ; PORTB configuration
    BANKSEL TRISB
    MOVLW   0b00001111		; set <RB0:RB3> PORTB pins as inputs to control keyboard -rows-
    MOVWF   TRISB
    BANKSEL ANSELH
    CLRF    ANSELH		; set PORTB as digital
    
    ; PORTC configuration
    BANKSEL TRISC
    CLRF    TRISC		; set <RC0:RC7> PORTC pins as outputs to control LEDs
    
    ; PORTD configuration
    BANKSEL TRISD
    CLRF    TRISD		; set <RD4:RD7> PORTD pins as outputs to control keyboard -columns-
    
    ; general port configuration
    BANKSEL OPTION_REG		; enable global pull-ups and set pre-scaler
    MOVLW   0b00000111		; | /RBPU | INTEDG | T0CS | T0SE | PSA | PS2 | PS1 | PS0 |
    MOVWF   OPTION_REG
    BANKSEL WPUB
    MOVLW   0b00001111		; enable pull-ups in <RB0:RB3> pins
    MOVWF   WPUB
    
    ; interruption configuration
    BANKSEL INTCON		; enable global interruptions and interruptions in PORTB
    MOVLW   0b10111000		; | GIE | PEIE | T0IE | INTE | RBIE | T0IF | INTF | RBIF |
    MOVWF   INTCON
    BANKSEL IOCB
    MOVLW   0b00001111		; enable interrupt-on-change in <RB0:RB3> pins
    MOVWF   IOCB
    
    ; TMR0 initialization
    BANKSEL TMR0
    CLRF    TMR0
    
    ; PORTB initialization
    BANKSEL PORTB
    CLRF    PORTB
    
    ; PORTC initialization
    BANKSEL PORTC
    CLRF    PORTC
    
    ; PORTD initialization
    BANKSEL PORTD
    CLRF    PORTD
    
    ; variables initialization
    CLRF    TMR0_CNTR
    CLRF    KYBRD_BTN
    CLRF    KYBRD_FND_F

; main program loop
main:
    
    ; show pressed button
    CALL    display
    
    GOTO    main
    
; interruption subroutine to control TMR0
TMR0ISR:
    CLRF    TMR0		; reset TMR0
    INCF    TMR0_CNTR		; increment TMR0 counter variable
    CALL    blinkLED
    BCF	    INTCON, 2		; clear T0IF bit
    RETURN

; interruption subroutine to get pressed button in keyboard
keyboardISR:
    
    ; clear previous found flag
    CLRF    KYBRD_FND_F
    
    ; search in column 0
    BCF	    PORTD, 4		; active only column 0
    BSF	    PORTD, 5
    BSF	    PORTD, 6
    BSF	    PORTD, 7
    MOVLW   0b00000001		; save current column
    MOVWF   KYBRD_BTN
    CALL    searchInRow		; find if the row is found with the current column
    BTFSC   KYBRD_FND_F, 0	; if the keyboard found flag is set return
    GOTO    $+29
    
    ; search in column 1
    BSF	    PORTD, 4
    BCF	    PORTD, 5		; active only column 1
    BSF	    PORTD, 6
    BSF	    PORTD, 7
    MOVLW   0b00000010		; save current column
    MOVWF   KYBRD_BTN
    CALL    searchInRow		; find if the row is found with the current column
    BTFSC   KYBRD_FND_F, 0	; if the keyboard found flag is set return
    GOTO    $+20
    
    ; search in column 2
    BSF	    PORTD, 4
    BSF	    PORTD, 5
    BCF	    PORTD, 6		; active only column 2
    BSF	    PORTD, 7
    MOVLW   0b00000100		; save current column
    MOVWF   KYBRD_BTN
    CALL    searchInRow		; find if the row is found with the current column
    BTFSC   KYBRD_FND_F, 0	; if the keyboard found flag is set return
    GOTO    $+11
    
    ; search in column 3
    BSF	    PORTD, 4
    BSF	    PORTD, 5
    BSF	    PORTD, 6
    BCF	    PORTD, 7		; active only column 3
    MOVLW   0b00001000		; save current column
    MOVWF   KYBRD_BTN
    CALL    searchInRow		; find if the row is found with the current column
    BTFSC   KYBRD_FND_F, 0	; if the keyboard found flag is set, return
    GOTO    $+2
    
    ; case if there is no match
    CLRF    KYBRD_BTN
    
    ; return from getKeyboard subroutine
    CLRF    PORTD
    BCF	    INTCON, 1		; clear INTF bit
    BCF	    INTCON, 0		; clear RBIF bit
    RETURN
    
; subroutine to find if there are any set bits in the row
searchInRow:
    BTFSS   PORTB, 0
    GOTO    $+8
    BTFSS   PORTB, 1
    GOTO    $+9
    BTFSS   PORTB, 2
    GOTO    $+10
    BTFSS   PORTB, 3
    GOTO    $+11
    RETURN
    
    ; set row 0
    BSF	    KYBRD_BTN, 4
    BSF	    KYBRD_FND_F, 0
    RETURN
    
    ; set row 1
    BSF	    KYBRD_BTN, 5
    BSF	    KYBRD_FND_F, 0
    RETURN
    
    ; set row 2
    BSF	    KYBRD_BTN, 6
    BSF	    KYBRD_FND_F, 0
    RETURN
    
    ; set row 3
    BSF	    KYBRD_BTN, 7
    BSF	    KYBRD_FND_F, 0
    RETURN
    
; subroutine to show the pressed button in display
display:
    MOVF    KYBRD_BTN, W
    CALL    kybrdToHexConv
    MOVWF   PORTC
    RETURN
    
; subroutine to convert a value in W by performing additions based on bit positions
kybrdToHexConv:
    
    ; clear W
    CLRW
    
    ; add bit 7 (accumulator + 0)
    BTFSS   KYBRD_BTN, 7
    GOTO    $+2
    ADDLW   0x00
    
    ; add bit 6 (accumulator + 1)
    BTFSS   KYBRD_BTN, 6
    GOTO    $+2
    ADDLW   0x01

    ; add bit 5 (accumulator + 2)
    BTFSS   KYBRD_BTN, 5
    GOTO    $+2
    ADDLW   0x02
	
    ; add bit 4 (accumulator + 3)
    BTFSS   KYBRD_BTN, 4
    GOTO    $+2
    ADDLW   0x03
	
    ; add bit 3 (accumulator + 0)
    BTFSS   KYBRD_BTN, 3
    GOTO    $+2
    ADDLW   0x00
	
    ; add bit 2 (accumulator + 4)
    BTFSS   KYBRD_BTN, 2
    GOTO    $+2
    ADDLW   0x04
	
    ; add bit 1 (accumulator + 8)
    BTFSS   KYBRD_BTN, 1
    GOTO    $+2
    ADDLW   0x08
	
    ; add bit 0 (accumulator + 12)
    BTFSS   KYBRD_BTN, 0
    GOTO    $+2
    ADDLW   0x0C

    ; add null
    MOVWF   KYBRD_BTN
    RETURN
    
; blink LED
blinkLED:
    BTFSS   PORTD, 0
    GOTO    $+2
    GOTO    $+3
    
    ; turn on LED
    BSF	    PORTD, 0
    RETURN

    ; turn off LED
    BCF	    PORTD, 0
    RETURN
	
END RESET_VECT