;-------------------------------------------------------------------------------
; MSP430 Assembler Code Template for use with TI Code Composer Studio
;
;-------------------------------------------------------------------------------
            .cdecls C,LIST,"msp430.h"       ; Include device header file for MSP430 definitions
            
;-------------------------------------------------------------------------------
            .def    RESET                   ; Define the entry point RESET for the linker.
;-------------------------------------------------------------------------------
            .text                           ; Assemble into program memory section.
            .retain                         ; Retain this section to prevent removal during linking.
            .retainrefs                     ; Retain any sections that reference this one.

;-------------------------------------------------------------------------------
RESET       mov.w   #__STACK_END,SP         ; Initialize stack pointer to end of stack.
StopWDT     mov.w   #WDTPW|WDTHOLD,&WDTCTL  ; Stop the watchdog timer.

ramS0Base	.equ 0x2400				; Base address of data in memory to be serialized.
OneKB		.equ 0x1024				; Define 1KB for memory operations.
numCount    .equ 35                          ; Number of bytes to transmit.
LED1 	.equ BIT0                           ; Define LED1 at P1.0.
LED2 	.equ BIT7                           ; Define LED2 at P4.7.
SW1		.equ BIT1		; Define SW1 at P2.1.
MUL       .equ 1                             ; Multiplier for delay subroutine.
		.define R4, counter                 ; Use R4 as a counter.
		.asg R12, ramS0Ptr                  ; Assign R12 as pointer to data to serialize.
		.define BIT0, SOUT		; Define SOUT (serial output) on P3.0.
		.define BIT1, SCLK		; Define SCLK (serial clock) on P3.1.

;-------------------------------------------------------------------------------
; Main loop initialization
;-------------------------------------------------------------------------------

INIT:
	bic.b #LED1, &P1OUT		; Clear LED1 output (set to 0).
	bis.b #LED1, &P1DIR            ; Set P1.0 (LED1) as output.
	bic.b #LED2, &P4OUT		; Clear LED2 output.
	bis.b #LED2, &P4DIR            ; Set P4.7 (LED2) as output.

    bic.b #SW1, &P2DIR             ; Set SW1 (P2.1) as input.
    bis.b #SW1, &P2REN             ; Enable pull-up/down resistor on SW1.
    bis.b #SW1, &P2OUT             ; Enable pull-up on SW1.
    
    bis.b   #SOUT|SCLK, &P3DIR     ; Set SOUT and SCLK as outputs.
    clr.w  &P3OUT                  ; Initialize SOUT to low.

MAIN_LOOP:
  push R12
  mov.w #ramS0Base, R12			; Load base address of data to serialize.
  clr counter

BYTE_LOOP:

SW_HIGH:
	bit.b #SW1, &P2IN		; Wait until SW1 is pressed.
	jnz SW_HIGH


SW_LOW:
	bit.b #SW1, &P2IN		; Wait until SW1 is released.
	jz SW_LOW

LED_T0GGGLE:
	xor #LED1,&P1OUT           ; Toggle LED1.
	call #PISO                  ; Call PISO subroutine to transmit data serially.
    inc ramS0Ptr                ; Move to next byte in data.
	inc.b counter               ; Increment byte counter.
	call #DELAY_10m             ; Delay to allow for pacing between transmissions.
    cmp #numCount, counter      ; Check if the required number of bytes has been transmitted.
    jnz BYTE_LOOP               ; If not, continue transmitting.
    pop R12
	jmp MAIN_LOOP               ; Repeat the main loop.

;--------------------------------------------------------------------------------------------------------
; Subroutine Delay_10m: Provides a scalable delay in increments of 10ms.
;
; Input:
; R12 - Specifies the delay multiplier (total delay = R12 * 10ms).
;
; Output: None
;---------------------------------------------------------------------------------------------------------
DELAY_10m:
			.asg R10, innerLoopCtr		; Define local variable for inner loop counter.
			.asg R12, outerLoopCtr      ; Define local variable for outer loop counter.

LOOP_10ms 	.equ 3333                    ; Define inner loop count for 10ms delay.

			push innerLoopCtr			; Save inner loop counter on stack.
	        push outerLoopCtr           ; Save outer loop counter on stack.
	        mov.w #MUL, outerLoopCtr    ; Initialize outer loop counter.
			jmp LOOP_TEST				; Jump to inner loop test.

DELAY_LOOP1:
			mov.w #LOOP_10ms, innerLoopCtr ; Initialize inner loop counter.
DELAY_LOOP2:								
			dec.w innerLoopCtr			; Decrement inner loop counter.
			jnz DELAY_LOOP2				; Repeat until inner loop counter reaches zero.

			dec.w outerLoopCtr			; Decrement outer loop counter.
LOOP_TEST:	cmp #0, outerLoopCtr		; Check if outer loop is complete.
			jnz DELAY_LOOP1				; If not, repeat outer loop.
            pop outerLoopCtr            ; Restore outer loop counter.
			pop innerLoopCtr			; Restore inner loop counter.
			ret							; Return from subroutine.

;--------------------------------------------------------------------------------------------------------
; Subroutine PISO (Parallel In Serial Out):
; Serializes a byte of data for transmission.
;
; Input:
; ramS0Ptr - Address of the data byte to serialize.
;
; Output: None
;---------------------------------------------------------------------------------------------------------
PISO:
           .asg R5, bitCtr			; Define bit counter.
			.asg R12, ramS0Ptr       ; Define pointer to data byte.
			.asg R7, byte             ; Define register for the byte.

	push bitCtr
	push byte
	mov.b @ramS0Ptr, R7         ; Load byte from memory into R7.
	mov #8, bitCtr              ; Initialize bit counter for 8 bits.

BIT_LOOP:
            rlc.b byte               ; Rotate byte left, moving MSB to carry.
            jc  SET_SOUT_HIGH        ; If carry bit is 1, set SOUT high.
            jmp SET_SOUT_LOW         ; If carry bit is 0, set SOUT low.

SET_SOUT_LOW:
            clr.w  &P3OUT            ; Set SOUT (P3.0) low.
            jmp CLOCK_PULSE          ; Proceed to clock pulse.

SET_SOUT_HIGH:
          mov.w #SOUT, &P3OUT        ; Set SOUT (P3.0) high.
			NOP						; Delay with no-operation instructions.
CLOCK_PULSE:
      bis.b #SCLK, &P3OUT            ; Generate clock pulse by setting SCLK high.

CHECK:
         dec bitCtr                  ; Decrement bit counter.
         jnz BIT_LOOP                ; Repeat until all bits are transmitted.

DONE:
    pop byte                          ; Restore saved registers.
	pop bitCtr
    ret                               ; Return from subroutine.

;-------------------------------------------------------------------------------
; Stack Pointer definition
;-------------------------------------------------------------------------------
            .global __STACK_END
            .sect   .stack
            
;-------------------------------------------------------------------------------
; Interrupt Vectors
;-------------------------------------------------------------------------------
            .sect   ".reset"                ; MSP430 RESET Vector
            .short  RESET                   ; Set the reset vector to RESET label.
