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

; Optimization-driven design:
; - Use the fact that the screen is split into 3 slices, and that code that
;	doesn't cross between slices can be made simpler. This is true for
;	both the bitmap and the attributes. In practice, make the attribute
;	scrolltext fill exactly the middle slice.
; - Make the vertical and horizontal bars move by at most one block per frame.
;	That way, they can be drawn incrementally.

; Drawing the vertical and horizontal bars:
; - Draw line by line
; - 4 types of line, based on status of horizontal bars:
;	* off -> off
;	* off -> on
;	* on -> off
;	* on -> on
; - 3 actions for vertical bars:
;	* move left
;	* move right
;	* no move
;	* with 8 possible horizontal positions for each (?)


#code text		; This code is is non-contended RAM
MainLoop:
  HALT

; There's a little bit of trickery here.
;
; The first step of the trickery is to compute the list of routines to call
; before calling them, and to store those on the stack (which means that they
; need to be in reverse order). That way, there's less back-and-forth
; between the code that figures out which routines to call and the actual
; code of those routines, i.e. there's less clobbering of registers.
;
; The second step of the trickery is to realize that calling a sequence
; of subroutines is annoying. It should look like a POP HL / CALL (HL),
; but that latter instruction doesn't exist, the sequence is instead
; POP HL / CALL nn / JP (HL), 31 cycles total, with each subroutine finishing
; with a RET which takes 10 cycles for a total of 41 cycles. It is instead
; better for each subroutine to jump to the next one directly,
; i.e. POP HL / JP (HL), which takes 14 cycles. Note that doing things this
; way also requires some special care so that the last subroutine in the list
; returns to the caller properly.
;
; The third step of the trickery is to realize that the POP HL / JP (HL)
; is in reality the RET instruction, which is a fancy name for POP PC.
; That instruction only takes 10 cycles (it's a POP after all) and doesn't
; clobber any register.
;
; The trickery as a whole is therefore to PUSH the continuation address on
; the stack, followed by the addresses of the various subroutines to call,
; in reverse order. Calling the first subroutine happens with a RET,
; each subroutine calls the next with a RET, and the last one returns to
; the main flow also with a RET (so it doesn't need to be special).
;
; Folks working with some RISC processors probably recognize some of those
; patterns. Also, the approach of mismatching CALL and RET instruction
; breaks speculative execution on modern processors, and is therefore used
; to mitigate vulnerabilities that rely on speculative execution, e.g.
; Meltdown and Spectre.

  LD HL, TopDone
  PUSH HL
  LD HL, DrawVLeft1
  .rept 4
  PUSH HL
  .endm
  LD HL, DrawVLeft0
  .rept 4
  PUSH HL
  .endm

  LD HL, attributes
  LD DE, 6
  LD BC, 8

  RET

TopDone:

  LD A, 1
  OUT ($fe), A
  LD B, 16
Wait1:
  DJNZ Wait1
  LD A, 0
  OUT ($fe), A

  JP MainLoop

; #############################################################################
; #############################################################################
; ###                                                                       ###
; ###                                                                       ###
; ###                          Drawing subroutines                          ###
; ###                                                                       ###
; ###                                                                       ###
; #############################################################################
; #############################################################################

; ################################
; ##                            ##
; ## Horizontal bars off -> off ##
; ##                            ##
; ################################

; Parameters:
; HL: address where to write
; B: contains 0 (color of background)
; C: contains 8 (color of vertical bars)
; DE contains 6 (offset between colums)

DrawVLeft0:
  .rept 4
  LD (HL), C
  INC L
  INC L
  LD (HL), B
  ADD HL, DE
  .endm
  RET

DrawVLeft1:
  INC L
  .rept 3
  LD (HL), C
  INC L
  INC L
  LD (HL), B
  ADD HL, DE
  .endm
  LD (HL), C
  INC L
  INC L
  LD (HL), B
  LD A, L
  ADD 5
  LD L, A
  RET


; Draw everything
; LD (HL), r	= 7 (8)
; INC HL	= 7 (8)
; 16 * 8 = 128
; * 4 per line = 512

; Alternative with push:
; PUSH rr	= 11 (16)
; 16 * 4 = 64
; * 4 per line = 256

; Alternative with direct drawing with IX/IY
; LD (IX + n), r = 19 (24)
; LD (IX + n), r = 19 (24)
; * 4 per line = 48 * 4 = 192
; + 15 to increment IX/IY = 208

; Directy drawing with HL
; LD (HL), r = 7 (8)
; INC HL * 2 = 8 (8)
; LD (HL), r = 7 (8)
; ADD L, 6 = 11/12 (12)
; * 4 per line = 36 * 4 = 144


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
