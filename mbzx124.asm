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

; Coding style:
;	- ASCII
;	- hard tabs, 8 characters wide, except in ASCII art
;	- 2 spaces from edge to instruction
;	- 1 space between instruction and parameter
;	- 80 columns total
;	- Per-instruction comments start at 3 tabs for assembly with
;		short instructions (Z80), 4 tabs for assembly with
;		long instructions (68000)
;
;	- Assembler directives are .lowercase with a leading period
;	- Mnemomics are lowercase when they typically read like words (move),
;		UPPERCASE when they read like acronyms (DJNZ).
;	- Registers are lowercase when they use multiple characters and are
;		uniquely recognizable (d0), UPPERCASE when they use
;		single characters (A)
;	- Symbols for code are CamelCase
;	- Symbols for variables are snake_case
;	- Symbols for app-specific constants are ALL_CAPS
;	- Symbols for OS constants, hardware registers are ALL_CAPS
;	- File-specific symbols start with an underscore
;	- Related symbols start with the same prefix (so they sort together)
;	- Hexadecimal constants are lowercase ($eaf00d).
;
;	- Include but comment out instructions that help readability but
;		don't do anything (e.g. redundant CLC on 6502 when the carry is
;		guaranteed already to be clear). The comment symbol should be
;		where the instruction would be, i.e. not on the first column.
;		There should be an explanation in a comment.
;	- Use the full instruction mnemonic whenever possible, and especially
;		when a shortcut would potentially cause confusion. E.g. use
;		movea instead of move on 680x0 when the code relies on the
;		flags not getting modified.

; #############################################################################
; #############################################################################
; ###                                                                       ###
; ###                                                                       ###
; ###                      Assembler setup directives                       ###
; ###                                                                       ###
; ###                                                                       ###
; #############################################################################
; #############################################################################

; ******************
; * zasm paramters *
; ******************

  .reqcolon		; labels are required to have colons
			;   that way zasm can recognize non-labels
  .dotnames		; labels are allowed to contain dots
			;   note that zasm doesn't make them local
  .z80			; We're on a ZX Spectrum

; ***************
; * output type *
; ***************

#target ram		; Create a plain binary image

; *****************
; * memory layout *
; *****************

; Contended RAM
#data screen, $4000, $1b00	; 6 kiB of screen bitmap
#data attributes, $4000, $1b00	; 0.75 kiB of screen attributes
#data slowbss, $5b00, $300	; 0.75 kiB of ULA variables
#code slowtext, $5e00, $2200	; 8.5 kiB of code in ULA RAM, right after BASIC

; Fast RAM
#code text, $8000, $7c00	; 31 kiB of code in CPU RAM
#data bss, $fC00, $1fd		; ~0.5 kB of variables in CPU RAM
#data irqvecs, $fdfd, $104	; ~0.25 kB for IM 2 interrupt handling
#data stack, $ff01, $ff		; ~0.25 kB of stack

; #############################################################################
; #############################################################################
; ###                                                                       ###
; ###                                                                       ###
; ###                              Boilerplate                              ###
; ###                                                                       ###
; ###                                                                       ###
; #############################################################################
; #############################################################################

#code	slowtext

; ########################
; ##                    ##
; ## Entry point, setup ##
; ##                    ##
; ########################

; disable interrupts
	di

; set up stack
	ld	sp, 0

; set up IM 2 boilerplate
	ld	a, $c3
	ld	hl, $fdfd
	ld	(hl), a
	inc	l
	ld	de, irq
	ld	(hl), e
	inc	l
	ld	(hl), d

	ld	c, $fd
	inc	h
	inc	l
	ld	b, l
SetIrq:	ld	(hl), c
	inc	l
	djnz	SetIrq
	inc	h
	ld	(hl), c

; set up interrupt handler
	ld	a, $fe
	ld	i, a

; enable interrupts
	im	2
	ei

; ##########################
; ##                      ##
; ## Display our graphics ##
; ##                      ##
; ##########################

	ld	a, $a5
	ld	($4000), a
	ld	($4200), a
	ld	($4500), a
	ld	($4700), a
	ld	a, 0
	ld	($4100), a
	ld	($4300), a
	ld	($4400), a
	ld	($4600), a
	ld	a, $46
	ld	($5800), a

; ###############################
; ##                           ##
; ## Get stuck in a tight loop ##
; ##                           ##
; ###############################

loop:	inc	a
	ld	(bgcolor), a
	jp	loop

; #######################
; ##                   ##
; ## Interrupt handler ##
; ##                   ##
; #######################

irq:	push	af
	ld	a, (bgcolor)
	rlca
	rlca
	rlca
	and	7
	out	($fe), a
	pop	af
	ei
	ret

; ########################################
; ##                                    ##
; ## Boilerplate for interrupt handling ##
; ##                                    ##
; ########################################

#data	bss
bgcolor:	ds	1
