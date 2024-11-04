;-------------------------------------------------------------------------------
; swSpiAsmb.asm
;
; MSP430 Software SPI Receiver
; This code implements a software SPI receiver using the MSP430 microcontroller.
; The receiver waits for clock edges and reads data bits serially,
; storing each byte in memory after receiving 8 bits.
;
; Author: Kai Nguyen, Jing Zhu, Lukas 
; Date: OCT 2024
;-------------------------------------------------------------------------------

            .cdecls C,LIST,"msp430.h"       ; Include device header file
            
;-------------------------------------------------------------------------------
            .def    RESET                   ; Define RESET as program entry point
;-------------------------------------------------------------------------------
            .text                           ; Start assembling into program memory
            .retain                         ; Retain this section in memory
            .retainrefs                     ; Retain sections referencing this section

;-------------------------------------------------------------------------------
RESET       mov.w   #__STACK_END,SP         ; Initialize stack pointer
StopWDT     mov.w   #WDTPW|WDTHOLD,&WDTCTL  ; Stop watchdog timer to prevent resets

;-------------------------------------------------------------------------------
; Main code here
;-------------------------------------------------------------------------------
BASE     	.equ 0x2400                     ; Base address in memory for received data storage
NUM         .equ 20                    		; Number of bytes to receive and store

            .define BIT0, SIN              ; Define SIN (Serial Input) on P3.0
            .define BIT1, SCLK             ; Define SCLK (Serial Clock) on P3.1
            .define BIT7, LED              ; Define LED on P4.7
            .define R4, ramS0ptr           ; Define R4 as pointer to data array in memory
            .define R13, regTemp           ; Define R13 as a temporary register

            .define R5, DATA               ; Define R5 to store received byte data
            .define R6, byteSize           ; Define R6 as byte size counter (for 8 bits per byte)
			.define R7, index              ; Define R7 as index to store data in memory

PORT_INIT:                                  ; Initialize ports for input and output
            bic.b #SIN, &P3DIR             ; Set P3.0 (SIN) as input
            bic.b #SCLK, &P3DIR            ; Set P3.1 (SCLK) as input
            bis.b #LED, &P4DIR				; Set P4.7 (LED) as output
            clr.w regTemp                  ; Clear temporary register

MAIN:                                       ; MAIN loop, continuously checks for incoming data
			clr index                     ; Clear index for data storage

BYTE:                                       ; Start of byte reception loop
			mov #8, byteSize              ; Set byteSize to 8 (for 8 bits per byte)
			clr DATA                      ; Clear DATA register to store incoming bits

CHECK_LOOP_LOW:                             ; Wait for clock signal to go low
			mov &P3IN, regTemp            ; Read P3 input register into regTemp
			bit.b #BIT1, regTemp          ; Check if SCLK (P3.1) is high
			jnz CHECK_LOOP_LOW            ; Loop until SCLK is low

CHECK_LOOP_HIGH:                            ; Wait for clock signal to go high
			mov &P3IN, regTemp            ; Read P3 input register into regTemp
			bit.b #BIT1, regTemp          ; Check if SCLK (P3.1) is low
			jz CHECK_LOOP_HIGH            ; Loop until SCLK goes high

STORE_DATA:                                 ; Capture bit data on rising edge of SCLK
			bit.b #BIT0, regTemp          ; Check value of SIN (P3.0) for incoming bit
			rlc.b DATA                    ; Rotate left through carry to add SIN bit into DATA
			dec byteSize                  ; Decrement byteSize counter
			jnz CHECK_LOOP_LOW            ; Repeat until all 8 bits are captured

DATA_MEMORY:                                ; Store received byte in memory
			mov.b DATA, BASE(index)       ; Store byte in memory at BASE + index
            inc index                     ; Increment index for next byte storage
            cmp index, &NUM               ; Compare index with NUM (20) to see if complete
            jnz BYTE                      ; If not done, receive next byte
			jmp MAIN                      ; Start over once all bytes are received
			nop                            ; No operation (padding instruction)

;-------------------------------------------------------------------------------
; Stack Pointer definition
;-------------------------------------------------------------------------------
            .global __STACK_END
            .sect   .stack                 ; Define stack section
            
;-------------------------------------------------------------------------------
; Interrupt Vectors
;-------------------------------------------------------------------------------
            .sect   ".reset"                ; MSP430 RESET Vector
            .short  RESET                   ; Set reset vector to entry point RESET
