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
#data	pixels, $5800, $300		; 0.75 kiB of screen attribute data
#code	text, $5e00, $400		; some amount of code, right after BASIC
#data	bss, $6e00, $100		; 0.25kiB of variables

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
	di

; Save IY register, which is reserved by the Spectrum ROM
	push	iy

; Save I register since it's a system register that we're modifying
	ld	a, i			; we can only access I through A
	push	af			; we must push all of AF to save A

; ************************************************
; * Configure our own interrupts                 *
; * Interrupt handler is at $7f7f                *
; * Interrupt table is 257 bytes of $7f at $8000 *
; ************************************************

; Configure I register
	ld	a, $7f
	ld	i, a

; Write interrupt table
	ld	hl, $8000
	ld	b, l			; L is 0 here, loop 256 times
setirq:
	ld	(hl), a			; A is still $7f
	inc	l			; we know that we're only touching one page
	djnz	setirq
	inc	h			; at this point L has wrapped around, so HL was $8000, now $8100
	ld	(hl), a			; and A is still $7f

; Write interrupt handler
	ld	h, a
	ld	l, a			; now HL is $7f7f
	ld	de, irq
	ld	(hl), $c3		; c3 is opcode for JP
	inc	l			; HL is $7f80 after that
	ld	(hl), e			; litte-endian
	inc	l			; HL is $7f81 after that
	ld	(hl), d

; *********************
; * Enable interrupts *
; *********************
	im	2
	ei

; #############################################################################
; #############################################################################
; ###                                                                       ###
; ###                                                                       ###
; ###         Clear screen, flash logo, set palette for next stage          ###
; ###                                                                       ###
; ###                                                                       ###
; #############################################################################
; #############################################################################

; ******************************
; * Set all attributes to grey *
; ******************************

	ld	hl, $5800
	ld	bc, 3			; b = 0 (256 loops), c = 3 - 768 total
grey:
	ld	(hl), $3f		; 3f is 00 111 111, i.e. grey bg/grey fg
	inc	l
	djnz	grey			; inner loop
	inc	h
	dec	c
	jr	nz, grey		; outer loop

; ***********************
; * Set border to black *
; ***********************

	ld	a, 0
	out	($fe), a

; ***************************
; * Clear whole framebuffer *
; ***************************

	ld	hl, $4000
	ld	bc, 24			; b = 0 (256 loops), c = 24 - 6144 total
clear:
	ld	(hl), 0
	inc	l
	djnz	clear			; inner loop
	inc	h
	dec	c
	jr	nz, clear		; outer loop

; ******************************************
; * Build a transient logo from attributes *
; ******************************************

  ld hl, $5800
  ld c, 24
SweepY:
  ld b, 32
SweepX:
  ld a, c
  cp 17
  jr nc, DoClear
  cp 9
  jr c, DoClear
  ld a, b
  cp 25
  jr nc, DoClear
  cp 9
  jr nc, NoClear
DoClear:
  ld (hl), $7		; 00 000 111 black bg, grey fg
NoClear:
  inc hl
  djnz SweepX
  push hl
  ld hl, irqcount
  ld a, (hl)
WaitVbl:
  cp (hl)
  jr z, WaitVbl
  pop hl
  dec c
  jr nz, SweepY

; ***************************************
; * Set up attributes for splash screen *
; ***************************************

SetBg:
  LD HL, $5800		; Address of the attributes
  LD DE, colors
  LD C, 24		; 24 rows of attributes
SetBgY:
  LD B, 16		; 32 columns of attributes, 2 per iteration
SetBgX:
; Do the actual read/write
  LD A, (DE)
  AND %00001000
  JR NZ, SetBg1Light
  LD A, (DE)
  AND %00000111
  JR SetBg1Done
SetBg1Light:
  LD A, (DE)
  AND %00000111
  OR %01000000
SetBg1Done:
  LD (HL), A
  INC HL

  LD A, (DE)
  AND %10000000
  JR NZ, SetBg2Light
  LD A, (DE)
  RRA
  RRA
  RRA
  RRA
  AND %00000111
  JR SetBg2Done
SetBg2Light:
  LD A, (DE)
  RRA
  RRA
  RRA
  RRA
  AND %00000111
  OR %01000000
SetBg2Done:
  LD (HL), A
  INC DE
  INC HL
; Loop within the row
  DJNZ SetBgX
; Wait for VBL
  PUSH HL
  LD HL, irqcount
  LD A, (HL)
SetBgWait:
  CP (HL)
  JR Z, SetBgWait
  POP HL
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

; Disable interrupts while we modify them
	di
; Restore I register
	pop	af
	ld	i, a
; Restore IY register
	pop	iy
; Enable interrupts back
	im	1
	ei
; Return to BASIC
	ret

; #############################################################################
; #############################################################################
; ###                                                                       ###
; ###                                                                       ###
; ###                           Interrupt handler                           ###
; ###                                                                       ###
; ###                                                                       ###
; #############################################################################
; #############################################################################

irq:
; Save what we use (AF)
	push	af
; Increment IRQ count
	ld	a, (irqcount)
	inc	a
	ld	(irqcount), a
; Restore what we used (AF)
	pop	af
; Terminate interrupt handler
	ei
	ret

; Background data
colors:
	.rept 24
	.db $99, $99, $99, $99, $99
	.db $79
	.db $77, $77, $77, $77
	.db $27
	.db $22, $22, $22, $22, $22
	.endm


#data	bss
irqcount:
	ds	1
