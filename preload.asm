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
; ###                              Boilerplate                              ###
; ###                                                                       ###
; ###                                                                       ###
; #############################################################################
; #############################################################################

#code	text
	di
	push	iy

	ld	a, i
	ld	(save_i), a

	ld	a, $7f
	ld	i, a

	ld	hl, $8000
	ld	b, l
setirq:
	ld	(hl), a
	inc	l
	djnz	setirq
	inc	h
	ld	(hl), a
	ld	h, a
	ld	l, a
	ld	de, irq
	ld	(hl), $c3
	inc	l
	ld	(hl), e
	inc	l
	ld	(hl), d

	im	2
	ei

	ld	hl, $5800
	ld	bc, 3
grey:
	ld	(hl), $3f
	inc	l
	djnz	grey
	inc	h
	dec	c
	jr	nz, grey

	ld	a, 0
	out	($fe), a

	ld	hl, $4000
	ld	bc, 24
clear:
	ld	(hl), $ff
	inc	l
	djnz	clear
	inc	h
	dec	c
	jr	nz, clear

	ld	hl, $5800
	ld	bc, 3
greyblack:
	ld	(hl), $7
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
	ld	(hl), 0
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
	ld	(hl), 0
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

	di
	im	1
	ld	a, (save_i)
	ld	i, a
	pop	iy
	ei
	ret

irq:	push	af
	ld	a, (irqcount)
	inc	a
	ld	(irqcount), a
	pop	af
	ei
	ret

#data	bss
irqcount:
	ds	1
save_i:
	ds	1
