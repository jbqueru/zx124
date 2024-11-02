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
#data attributes, $5800, $300	; 0.75 kiB of screen attributes
#data slowbss, $5b00, $300	; 0.75 kiB of ULA variables
#code slowtext, $5e00, $2200	; 8.5 kiB of code in ULA RAM, right after BASIC

; Fast RAM
#code text, $8000, $7000	; 28 kiB of code in CPU RAM
#data bss, $f000, $dfd		; ~3.5 kB of variables in CPU RAM
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

#code slowtext

; #################
; ##             ##
; ## Basic setup ##
; ##             ##
; #################

; disable interrupts
  DI

; set up stack
  LD SP, 0

; ##########################
; ##                      ##
; ## IM 2 interrupt setup ##
; ##                      ##
; ##########################

	ld	a, $c3
	ld	hl, $fdfd
	ld	(hl), a
	inc	l
	ld	de, IrqVbl
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

; Wait half a second
  LD B, 25
Pause:
  HALT
  DJNZ Pause

; ######################
; ##                  ##
; ## Clear the screen ##
; ##                  ##
; ######################

; Wait for VBL to avoid tearing
  HALT

; Set black border
  XOR A			; Cheap way to clear A
  OUT ($fe), A

; Clear attribute block
; Do it first so that the screen appears all black in a single frame
  ; XOR A		; A is still 0 here
  LD HL, $5800
  LD B, 3
ClearAttributes:
  LD (HL), A
  INC L
  JR NZ, ClearAttributes
  INC H
  DJNZ ClearAttributes

; Clear screen block
  ; XOR A		; A is still 0 here
  LD HL, $4000
  LD B, 24
ClearScreen:
  LD (HL), A
  INC L
  JR NZ, ClearScreen
  INC H
  DJNZ ClearScreen

  JP MainLoop

; #############################################################################
; #############################################################################
; ###                                                                       ###
; ###                                                                       ###
; ###                               Main loop                               ###
; ###                                                                       ###
; ###                                                                       ###
; #############################################################################
; #############################################################################

; Design goal:
; - various display elements as pseudo-bitplanes in paper attribute
;	* scrolltext, middle third, probably green because it's brighter
;	* vertical and horizontal bars
;	* brightness as a spotlight
; - some bitmaps, technically that can exist anywhere on screen, using the
; 	ink color. Top and bottom thirds are good candidates because the
;	scrolltext isn't there, and because they're easier to use when
;	racing the beam.

; performance-wise, copying the whole attribute table with LDIR takes
; 768 * 21 = 16128 cycles, out of 69888 for the whole frame.

#code text

MainLoop:
  HALT

  LD HL, attbuffer
  LD DE, $5800
  LD BC, 768
  LDIR

  LD A, 6
  OUT ($fe), A
  LD B, 10
Wait1:
  DJNZ Wait1
  LD A, 0
  OUT ($fe), A

  LD HL, attbuffer
  LD (HL), A
  LD D, H
  LD E, L
  INC DE
  LD BC, 767
  LDIR

  LD DE, Logo
  LD HL, attbuffer + 256
  LD B, 0
AddLogo:
  LD A, (DE)
  OR (HL)
  LD (HL), A
  INC DE
  INC HL
  DJNZ AddLogo

  LD A, 5
  OUT ($fe), A
  LD B, 10
Wait2:
  DJNZ Wait2
  LD A, 0
  OUT ($fe), A


  LD HL, attbuffer + 64
  LD B, 64
AddBar1:
  LD A, (HL)
  OR $10
  LD (HL), A
  INC HL
  DJNZ AddBar1

  LD HL, attbuffer + 320
  LD B, 64
AddBar2:
  LD A, (HL)
  OR $10
  LD (HL), A
  INC HL
  DJNZ AddBar2

  LD HL, attbuffer + 576
  LD B, 64
AddBar3:
  LD A, (HL)
  OR $10
  LD (HL), A
  INC HL
  DJNZ AddBar3

  LD A, 4
  OUT ($fe), A
  LD B, 10
Wait3:
  DJNZ Wait3
  LD A, 0
  OUT ($fe), A

  LD HL, attbuffer + 2
  LD DE, 31
  LD B, 24
AddColumn1:
  LD A, (HL)
  OR $8
  LD (HL), A
  INC HL
  LD A, (HL)
  OR $8
  LD (HL), A
  ADD HL, DE
  DJNZ AddColumn1

  LD HL, attbuffer + 10
  LD DE, 31
  LD B, 24
AddColumn2:
  LD A, (HL)
  OR $8
  LD (HL), A
  INC HL
  LD A, (HL)
  OR $8
  LD (HL), A
  ADD HL, DE
  DJNZ AddColumn2

  LD HL, attbuffer + 18
  LD DE, 31
  LD B, 24
AddColumn3:
  LD A, (HL)
  OR $8
  LD (HL), A
  INC HL
  LD A, (HL)
  OR $8
  LD (HL), A
  ADD HL, DE
  DJNZ AddColumn3

  LD HL, attbuffer + 26
  LD DE, 31
  LD B, 24
AddColumn4:
  LD A, (HL)
  OR $8
  LD (HL), A
  INC HL
  LD A, (HL)
  OR $8
  LD (HL), A
  ADD HL, DE
  DJNZ AddColumn4

  LD A, 3
  OUT ($fe), A
  LD B, 10
Wait4:
  DJNZ Wait4
  LD A, 0
  OUT ($fe), A

  JP MainLoop

; #############################################################################
; #############################################################################
; ###                                                                       ###
; ###                                                                       ###
; ###                           Interrupt handler                           ###
; ###                                                                       ###
; ###                                                                       ###
; #############################################################################
; #############################################################################

IrqVbl:
  PUSH HL
  LD HL, vbl_count
  INC (HL)
  POP HL
  EI
  RET

; #############################################################################
; #############################################################################
; ###                                                                       ###
; ###                                                                       ###
; ###                                 Data                                  ###
; ###                                                                       ###
; ###                                                                       ###
; #############################################################################
; #############################################################################

Logo:
  .rept 8
  .db $20, $20, $00, $00, $00, $20, $20, $00
  .endm
  .rept 4
  .db $20, $20, $20, $00, $20, $20, $20, $00
  .endm
  .rept 4
  .db $20, $20, $20, $20, $20, $20, $20, $00
  .endm
  .rept 4
  .db $20, $20, $00, $20, $00, $20, $20, $00
  .endm
  .rept 12
  .db $20, $20, $00, $00, $00, $20, $20, $00
  .endm

; ########################################
; ##                                    ##
; ## Boilerplate for interrupt handling ##
; ##                                    ##
; ########################################

#data	bss
vbl_count:
	.ds	1

attbuffer:
  .ds 768
