; Copyright 2024 Jean-Baptiste M. "JBQ" "Djaybee" Queru
;
; This program is free software: you can redistribute it and/or modify
; it under the terms of the GNU Affero General Public License as
; published by the Free Software Foundation, either version 3 of the
; License, or (at your option) any later version.
;
; As an added restriction, if you make the program available for
; third parties to use on hardware you own (or co-own, lease, rent,
; or otherwise control,) such as public gaming cabinets (whether or
; not in a gaming arcade, whether or not coin-operated or otherwise
; for a fee,) the conditions of section 13 will apply even if no
; network is involved.
;
; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
; GNU Affero General Public License for more details.
;
; You should have received a copy of the GNU Affero General Public License
; along with this program. If not, see <https://www.gnu.org/licenses/>.
;
; SPDX-License-Identifier: AGPL-3.0-or-later

; #############################################################################
; #############################################################################
; ###                                                                       ###
; ###                                                                       ###
; ###        Demo preloader - screen setup before loading bulk data         ###
; ###                                                                       ###
; ###                                                                       ###
; #############################################################################
; #############################################################################

; This prepares the display before loading the splash screen, so that the
;         splash screen loads directly with the right colors.
; * Clear the bitmap while the display is gray.
;     - first do it by clearing the attributes, which is faster.
;     - then clear the actual bitmap.
; * Display MB logo.
;     - sweep from the top of the screen and change non-logo parts to black.
; * Set the attributes to prepare for the splash screen.
;     - sweep from the top of the screen, set all attributes to match the
;             splash screen (with black background).
;
; Note: this code runs while the tape is running, so it can't take too
;         long or the next tape block with occur before the code is ready
;         to load it.

; #############################################################################
; #############################################################################
; ###                                                                       ###
; ###                                                                       ###
; ###                      Assembler setup directives                       ###
; ###                                                                       ###
; ###                                                                       ###
; #############################################################################
; #############################################################################

	.reqcolon			; labels are required to have colons - that way zasm can recognize non-labels
	.dotnames			; labels are allowed to contain dots - note that zasm doesn't make them local
	.z80				; We're on a ZX Spectrum

#target ram				; Create a plain binary image

; Contended RAM
#data	screen, $4000, $1800		; 6 kiB of screen bitmap data
#data	colors, $5800, $300		; 0.75 kiB of screen attribute data
#code	text, $5e00, $250		; some amount of code, right after BASIC

; #############################################################################
; #############################################################################
; ###                                                                       ###
; ###                                                                       ###
; ###                          Initial boilerplate                          ###
; ###                                                                       ###
; ###                                                                       ###
; #############################################################################
; #############################################################################

#code	text

; ********************************************
; * Disable interrupts, save important state *
; ********************************************

; Interrupts off so that we can start messing with things
  DI

; Save I register since it's a system register that we're modifying
  LD A, I		; we can only access I through A
  PUSH AF		; we must push all of AF to save A

; ************************************************
; * Configure our own interrupts                 *
; * Interrupt handler is at $7f7f                *
; * Interrupt table is 257 bytes of $7f at $8000 *
; ************************************************

; Configure I register
  LD A, $7f		; Set A to $7f, and we'll use it multiple times
  LD I, A

; Write interrupt table
; Optipmization: instead of incrementing HL for each write, we know we have
;	256 + 1 writes and that HL starts aligned on a page boundary,
;	so we increment L, let it wrap around, and increment H
  LD HL, $8000
  LD B, L		; L is 0 here (from HL), i.e. loop 256 times

SetupIrq:
  ; LD A, $7f		; A is still $7f
  LD (HL), A
  INC L			; we know this loop doesn't cross page boundaries
  DJNZ SetupIrq
  INC H			; L has wrapped back to 0, HL is $8000, make it $8100
  ; LD A, $7f		; A is still $7f
  LD (HL), A

; Write raw interrupt handler
  ; LD A, $7f		; A is still $7f
  LD H, A
  LD L, A		; now HL is $7f7f
  LD (HL), opcode(JP nn)
  INC L			; HL is $7f80 after that
  LD DE, IrqHandler
  LD (HL), E		; Z80 is litte-endian, start with low byte
  INC L			; HL is $7f81 after that
  LD (HL), D		; and the high byte of the address

; *********************
; * Enable interrupts *
; *********************
  IM 2
  EI

; #############################################################################
; #############################################################################
; ###                                                                       ###
; ###                                                                       ###
; ###        Clear screen, flash logo, set attributes for next stage        ###
; ###                                                                       ###
; ###                                                                       ###
; #############################################################################
; #############################################################################

; **************************************************
; * Set all attributes to pure gray                *
; * That way, whatever is in the bitmap disappears *
; **************************************************

  LD HL, colors		; Destination = start address of color attributes
  LD BC, 3		; b = 0 (256 loops), c = 3, i.e. 768 total

SetGray:
  LD (HL), $3f		; 3f is 00 111 111, i.e. gray bg/gray fg
  INC L
  DJNZ SetGray		; inner loop
  INC H
  DEC C
  JR NZ, SetGray	; outer loop

; ***********************
; * Set border to black *
; ***********************

  LD A, 0
  OUT ($fe), A

; ***************************
; * Clear whole framebuffer *
; ***************************

  LD HL, screen		; Destination = start address of framebuffer
  LD BC, 24		; b = 0 (256 loops), c = 24 - 6144 total

FbClear:
  LD (HL), 0
  INC L
  DJNZ FbClear		; inner loop
  INC H
  DEC C
  JR NZ, FbClear	; outer loop

; ******************************************
; * Build a transient logo from attributes *
; ******************************************

; Initialize pointers
  LD IX, gfx_logo	; Source data = logo bitmap
  LD HL, colors		; Destination = color attributes
  LD C, 24		; 24 rows per screen

SweepRow:
  LD B, 32		; 32 columns per row

SweepColumn:

; Check whether we're outside the logo area
  LD A, C
  CP 17
  JR NC, SweepClear	; above (row >= 17 from range 24..1)
  CP 9
  JR C, SweepClear	; below (row < 9 from range 24..1)
  LD A, B
  CP 25
  JR NC, SweepClear	; left (column >= 25 from range 32..1)
  CP 9
  JR C, SweepClear	; right (column < 9 from range 32..1)
  AND %00000111		; column multiple of 8? (i.e. 24 or 16)
  JR NZ, SweepGotData	; if no, we already have data
  LD D, (IX)		; if yes, get a new byte
  INC IX
SweepGotData:

; In logo area, check whether we have a pixel
  SLA D
  JR C, SweepClearDone	; We have a pixel: preserve attribute until next pass

; Clear the color attribute
SweepClear:
  LD (HL), 0		; All black

; Next column
SweepClearDone:
  INC HL
  DJNZ SweepColumn

; Wait for VBL between rows
  HALT

; Next row
  DEC C
  JR NZ, SweepRow

; ***************************************
; * Set up attributes for splash screen *
; ***************************************

SetBg:
  LD DE, gfx_colors	; source address: colors
  LD HL, colors		; destination address: screen attributes
  LD C, 24		; 24 rows of attributes

SetBgY:
  LD B, 16		; 32 columns of attributes, 2 per iteration

SetBgX:
; Left color in color pair
  LD A, (DE)
  AND %10000000		; attribute bit of high nybble : set = bright color
  JR NZ, SetBg1Light

; Left pair, dark variant
SetBg1Dark:
  LD A, (DE)
  RRA			; shift color 4 bits to the right
  RRA
  RRA
  RRA
  AND %00000111		; clear unwanted bits
  JR SetBg1Done

; Left pair, light variant
SetBg1Light:
  LD A, (DE)
  RRA			; shift color 4 bites to the right
  RRA
  RRA
  RRA
  AND %00000111		; clear unwanted bits
  OR %01000000		; set brightness bit
  ; JR SetBg1Done	; fall through

SetBg1Done:
  LD (HL), A		; write attributes
  INC HL		; next attribute block

; Right color in color pair
  LD A, (DE)		; attribute bit
  AND %00001000		; attribute bit of low nybble : set = bright color
  JR NZ, SetBg2Light

; Right pair, dark variant
SetBg2Dark:
  LD A, (DE)
  AND %00000111		; clear unwanted bits
  JR SetBg2Done

; Right pair, light variant
SetBg2Light:
  LD A, (DE)
  AND %00000111		; clear unwanted bits
  OR %01000000		; set brightness bit
  ; JR SetBg2Done	; fall through

SetBg2Done:
  LD (HL), A		; write attributes
  INC HL		; next attribute block
  INC DE		; next color pair

; Loop within the row
  DJNZ SetBgX
; Wait for VBL
  HALT
; Loop to next row
  DEC C
  JR NZ, SetBgY

; #############################################################################
; #############################################################################
; ###                                                                       ###
; ###                                                                       ###
; ###                           Final boilerplate                           ###
; ###                                                                       ###
; ###                                                                       ###
; #############################################################################
; #############################################################################

; Disable interrupts while we modify the interrupt setup
  DI
; Restore I register
  POP AF
  LD I, A
; Enable interrupts back
  IM 1
  EI
; Return to BASIC
  RET

; #############################################################################
; #############################################################################
; ###                                                                       ###
; ###                                                                       ###
; ###                           Interrupt handler                           ###
; ###                                                                       ###
; ###                                                                       ###
; #############################################################################
; #############################################################################

IrqHandler:
; Exit interrupt handler
  EI
  RET

; #############################################################################
; #############################################################################
; ###                                                                       ###
; ###                                                                       ###
; ###                             Graphics data                             ###
; ###                                                                       ###
; ###                                                                       ###
; #############################################################################
; #############################################################################

; ***********
; * MB logo *
; ***********

; 16x8, stored as plain bitmap, MSB on the left

gfx_logo:
  .db %11000110, %01111110
  .db %11000110, %01100011
  .db %11101110, %01100011
  .db %11111110, %01111110
  .db %11010110, %01100011
  .db %11000110, %01100011
  .db %11000110, %01100011
  .db %11000110, %01111110

; **************************************
; * Color attributes for splash screen *
; **************************************

; Packed, 1 color per nybble, MSB on the left
; Within each nybble, MSB is the brightness attribute

gfx_colors:
  .rept 24
  .db $99, $99, $99, $99, $99
  .db $97
  .db $77, $77, $77, $77
  .db $72
  .db $22, $22, $22, $22, $22
  .endm
