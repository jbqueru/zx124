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
#code	text, $5e00, $100		; some amount of code, right after BASIC
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

  ld hl, $5800
  ld c, 24
SweepY:
  ld b, 32
SweepX:
  ld (hl), $7		; 00 000 111 black bg, grey fg
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

#if 0
	ld	hl, $5800
	ld	bc, 3
greyblack:
	ld	(hl), $38		; 38 is 00 111 000, grey bg / black fg
	inc	l
	djnz	greyblack
	inc	h
	dec	c
	jr	nz, greyblack


	ld	hl, $4000
	ld	d, 3
sweep3:
	ld	c, 0
sweep2:
	ld	a, d
	cp	2
	jr	nz, notlogo
	ld	a, c
	dec	a
	and	31
	cp	24
	jr	nc, notlogo
	cp	8
	jr	c, notlogo
	jr	pixeldone
notlogo:
	ld	b, 8
sweep1:
	ld	(hl), $ff
	inc	h
	djnz	sweep1
	ld	a, h
	sub	8
	ld	h, a
pixeldone:
	inc	l
wait:
	djnz	wait
	dec	c
	jp	nz, sweep2
	ld	a, h
	add	8
	ld	h, a
	dec	d
	jp	nz, sweep3

	ld	hl, $4000
	ld	d, 3
clear3:
	ld	c, 0
clear2:
	ld	b, 8
clear1:
	ld	(hl), $ff
	inc	h
	djnz	clear1
	ld	a, h
	sub	8
	ld	h, a
	inc	l
clear0:
	djnz	clear0
	dec	c
	jp	nz, clear2
	ld	a, h
	add	8
	ld	h, a
	dec	d
	jp	nz, clear3
#endif

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

#data	bss
irqcount:
	ds	1
