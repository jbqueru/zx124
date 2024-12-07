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

; Starting at address $fe00, we have 257 bytes of $fd. That way, with the
; I register set to $fe, no matter what's on the data bus, the CPU will
; jump to address $fdfd. In turn, $fdfd contains a JP instruction to the
; real interrupt handler.
;
; It's a nice fit, the JP instruction takes exactly the top 3 of the page
; at $fd, the $fe page is filled, and the first byte of the $ff page is
; used, which leaves space for a 255-byte stack in the $ff page.

  LD HL, $fdfd		; Start to write data at $fdfd

; Write the JP instruction
  LD A, opcode(JP nn)
  LD (HL), A		; Write the JP opcode
  INC L			; HL is now $fdfe
  LD DE, IrqVbl
  LD (HL), E		; Little-endian, write low byte first
  INC L			; HL is now $fdff
  LD (HL), D		; write high byte
  INC HL		; HL is now $fe00

; Write the first 256 bytes of the IM 2 vectors
  LD A, $fd
  LD B, L		; L is $00, so B is 0, i.e. loop 256 times
SetIrq:
  LD (HL), A
  INC L			; We're staying within the same page
  DJNZ SetIrq

; Write the last byte of the IM 2 vectors
  INC H			; HL was $fe00 (L had wrapped around), now $ff00
  LD (HL), A

; Set up interrupt control vector register
  LD A, $fe
  LD I, A

; Enable interrupts in mode 2
  IM 2
  EI

; ##########################
; ##                      ##
; ## Wait half a second   ##
; ##                      ##
; ## To see splash screen ##
; ## on emulators         ##
; ##                      ##
; ##########################

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
  XOR A
  LD HL, attributes
  LD B, 3
ClearAttributes:
  LD (HL), A
  INC L
  JR NZ, ClearAttributes	; Here JP would be faster but bigger
  INC H
  DJNZ ClearAttributes

; Clear screen block
  XOR A
  LD HL, screen
  LD B, 24
ClearScreen:
  LD (HL), A
  INC L
  JR NZ, ClearScreen	; Here JP would be faster but bigger
  INC H
  DJNZ ClearScreen

; Set attributes
  LD HL, attributes
  LD D, 3
SetScreen0:
  LD B, 8
SetScreen1:
  LD A, %01011111
  .rept 2
  LD (HL), A
  INC L
  .endm
  LD A, %01010111
  .rept 6
  LD (HL), A
  INC L
  .endm
  DJNZ SetScreen1
  LD B, 24
SetScreen2:
  LD A, %01001111
  .rept 2
  LD (HL), A
  INC L
  .endm
  LD A, %01000111
  .rept 6
  LD (HL), A
  INC L
  .endm
  DJNZ SetScreen2
  INC H
  DEC D
  JR NZ, SetScreen0

  JP MainLoop		; The rest of the code is in non-contended RAM

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
  HALT			; Wait for a VBL

; There's a little bit of trickery here, though I don't think it's as
; uncommon a technique as it seems.
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
; That instruction only takes 10 cycles (it's a POP after all, so it
; takes the same duration as a plain POP since the Z80 doesn't prefetch),
; and doesn't clobber any register.
;
; The trickery as a whole is therefore to PUSH the continuation address on
; the stack, followed by the addresses of the various subroutines to call,
; in reverse order. Calling the first subroutine happens with a RET,
; each subroutine calls the next with a RET, and the last one returns to
; the main flow also with a RET (so the last subroutine exits like the other
; ones and therefore doesn't need anything special).
;
; Folks working with some RISC processors probably recognize some of those
; patterns. Also, the approach of mismatching CALL and RET instruction
; breaks speculative execution on modern processors, and is therefore used
; to mitigate vulnerabilities that rely on speculative execution, e.g.
; Meltdown and Spectre.

; ################################
; ##                            ##
; ## Update display coordinates ##
; ##                            ##
; ################################

  LD HL, vbars_x
  LD A, (HL)
  DEC A
  AND 7
;  LD (HL), A

  LD HL, text_x
  LD A, (HL)
  INC A
  AND 31
;  LD (HL), A

; ######################################
; ##                                  ##
; ## Draw the top third of the screen ##
; ##                                  ##
; ######################################

; Push the address we'll jump to once we're done
  LD HL, TopDone
  PUSH HL

; Compute the address of the routine that matches the bars' X coordinate
  LD A, (vbars_x)
  ADD A
  LD E, A
  LD D, 0
  LD HL, DrawVList
  ADD HL, DE
  LD E, (HL)
  INC HL
  LD D, (HL)

; Write the computed address 8 times on the stack
  .rept 8
;  PUSH DE
  .endm

  LD HL, DrawHVLeft0

; Prepare parameters for subroutines
  LD HL, attributes	; Destination address

  LD DE, 6		; must be 6, to skip unchanged columns
  LD BC, $0800		; the colors we write, B then C

; Jump to the first routine
  RET

TopDone:

; Draw a timing line
  LD A, 1
  OUT ($fe), A
  LD B, 16
Wait1:
  DJNZ Wait1
  LD A, 0
  OUT ($fe), A

; #########################################
; ##                                     ##
; ## Draw the middle third of the screen ##
; ##                                     ##
; #########################################

; Push the address we'll jump to once we're done
  LD HL, MiddleDone
  PUSH HL

; Compute the address of the routine that matches the bars' X coordinate
  LD A, (vbars_x)
  ADD A
  ADD A
  LD E, A
  LD D, 0
  LD HL, DrawTextList
  ADD HL, DE
  LD E, (HL)
  INC HL
  LD D, (HL)
  INC HL
  LD C, (HL)
  INC HL
  LD B, (HL)

  LD HL, TextNextPage

; Write the computed address 8 times on the stack
  PUSH DE
  PUSH DE
  PUSH DE
  PUSH DE
  PUSH HL
  PUSH DE
  PUSH DE
  PUSH BC
  PUSH BC

; Prepare parameters for subroutines
  LD HL, Logo		; Source address
  LD A, (text_x)
  LD L, A
  LD DE, attributes + $100 ; Destination address

; Jump to the first routine
  RET

MiddleDone:

; Draw a timing line
  LD A, 2
  OUT ($fe), A
  LD B, 16
Wait2:
  DJNZ Wait2
  LD A, 0
  OUT ($fe), A

; #########################################
; ##                                     ##
; ## Draw the bottom third of the screen ##
; ##                                     ##
; #########################################

  LD HL, BottomDone
  PUSH HL

  LD A, (vbars_x)
  ADD A
  LD E, A
  LD D, 0
  LD HL, DrawVList
  ADD HL, DE
  LD E, (HL)
  INC HL
  LD D, (HL)

  .rept 8
;  PUSH DE
  .endm

  LD HL, attributes + $200
  LD DE, 6
  LD BC, $0800

  RET
BottomDone:

  LD A, 3
  OUT ($fe), A
  LD B, 16
Wait3:
  DJNZ Wait3
  LD A, 0
  OUT ($fe), A

  LD HL, SpriteWilly + 0
  LD DE, $5063
  LD B, 2
SpriteDraw:
  .rept 8
  LD A, (HL)
  INC L
  LD (DE), A
  INC D
  .endm
  LD A, E
  ADD 32
  LD E, A
  LD A, D
  SUB 8
  LD D, A
  DJNZ SpriteDraw

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

; B.C.....
DrawVLeft0:
  .rept 4
  LD (HL), B
  INC L
  INC L
  LD (HL), C
  ADD HL, DE
  .endm
  RET

; .B.C....
DrawVLeft1:
  INC L
  .rept 3
  LD (HL), B
  INC L
  INC L
  LD (HL), C
  ADD HL, DE
  .endm
  LD (HL), B
  INC L
  INC L
  LD (HL), C
  LD A, L
  ADD 5
  LD L, A
  RET

; ..B.C...
DrawVLeft2:
  INC L
  INC L
  .rept 3
  LD (HL), B
  INC L
  INC L
  LD (HL), C
  ADD HL, DE
  .endm
  LD (HL), B
  INC L
  INC L
  LD (HL), C
  LD A, L
  ADD 4
  LD L, A
  RET

; ...B.C..
DrawVLeft3:
  INC L
  INC L
  INC L
  .rept 3
  LD (HL), B
  INC L
  INC L
  LD (HL), C
  ADD HL, DE
  .endm
  LD (HL), B
  INC L
  INC L
  LD (HL), C
  INC L
  INC L
  INC L
  RET

; ....B.C.
DrawVLeft4:
  LD A, L
  ADD 4
  LD L, A
  .rept 3
  LD (HL), B
  INC L
  INC L
  LD (HL), C
  ADD HL, DE
  .endm
  LD (HL), B
  INC L
  INC L
  LD (HL), C
  INC L
  INC L
  RET

; .....B.C
DrawVLeft5:
  LD A, L
  ADD 5
  LD L, A
  .rept 3
  LD (HL), B
  INC L
  INC L
  LD (HL), C
  ADD HL, DE
  .endm
  LD (HL), B
  INC L
  INC L
  LD (HL), C
  INC L
  RET

; C.....B.
DrawVLeft6:
  .rept 4
  LD (HL), C
  ADD HL, DE
  LD (HL), B
  INC L
  INC L
  .endm
  RET

; .C.....B
DrawVLeft7:
  .rept 4
  INC L
  LD (HL), C
  ADD HL, DE
  LD (HL), B
  INC L
  .endm
  RET

DrawVList:
	.dw	DrawVLeft0, DrawVLeft1, DrawVLeft2, DrawVLeft3
	.dw	DrawVLeft4, DrawVLeft5, DrawVLeft6, DrawVLeft7

; BBCCCCCC
DrawHVLeft0:
  .rept 4
  .rept 2
  LD (HL), B
  INC L
  .endm
  .rept 6
  LD (HL), C
  INC L
  .endm
  .endm
  RET

; ########################################
; ##                                    ##
; ## Scrolltext without horizontal bars ##
; ##                                    ##
; ########################################

; Parameters/return:
; ABC: ignored/clobbered
; DE: destination address
; HL: source address

; ****************************************
; ** Vertical bars at positions 0 and 1 **
; ****************************************

TextVBar01:
  .rept 4
  .rept 2
  LD A, (HL)
  OR 8
  LD (DE), A
  INC L
  INC E
  .endm
  .rept 6
  LDI
  .endm
  .endm
  LD A, L
  ADD 32
  LD L, A
  RET

; ****************************************
; ** Vertical bars at positions 1 and 2 **
; ****************************************

TextVBar12:
  .rept 4
  LDI
  .rept 2
  LD A, (HL)
  OR 8
  LD (DE), A
  INC L
  INC E
  .endm
  .rept 5
  LDI
  .endm
  .endm
  LD A, L
  ADD 32
  LD L, A
  RET

; ****************************************
; ** Vertical bars at positions 2 and 3 **
; ****************************************

TextVBar23:
  .rept 4
  .rept 2
  LDI
  .endm
  .rept 2
  LD A, (HL)
  OR 8
  LD (DE), A
  INC L
  INC E
  .endm
  .rept 4
  LDI
  .endm
  .endm
  LD A, L
  ADD 32
  LD L, A
  RET

; ****************************************
; ** Vertical bars at positions 3 and 4 **
; ****************************************

TextVBar34:
  .rept 4
  .rept 3
  LDI
  .endm
  .rept 2
  LD A, (HL)
  OR 8
  LD (DE), A
  INC L
  INC E
  .endm
  .rept 3
  LDI
  .endm
  .endm
  LD A, L
  ADD 32
  LD L, A
  RET

; ****************************************
; ** Vertical bars at positions 4 and 5 **
; ****************************************

TextVBar45:
  .rept 4
  .rept 4
  LDI
  .endm
  .rept 2
  LD A, (HL)
  OR 8
  LD (DE), A
  INC L
  INC E
  .endm
  .rept 2
  LDI
  .endm
  .endm
  LD A, L
  ADD 32
  LD L, A
  RET

; ****************************************
; ** Vertical bars at positions 5 and 6 **
; ****************************************

TextVBar56:
  .rept 4
  .rept 5
  LDI
  .endm
  .rept 2
  LD A, (HL)
  OR 8
  LD (DE), A
  INC L
  INC E
  .endm
  LDI
  .endm
  LD A, L
  ADD 32
  LD L, A
  RET

; ****************************************
; ** Vertical bars at positions 6 and 7 **
; ****************************************

TextVBar67:
  .rept 4
  .rept 6
  LDI
  .endm
  .rept 2
  LD A, (HL)
  OR 8
  LD (DE), A
  INC L
  INC E
  .endm
  .endm
  LD A, L
  ADD 32
  LD L, A
  RET

; ****************************************
; ** Vertical bars at positions 7 and 0 **
; ****************************************

TextVBar70:
  .rept 4
  LD A, (HL)
  OR 8
  LD (DE), A
  INC L
  INC E
  .rept 6
  LDI
  .endm
  LD A, (HL)
  OR 8
  LD (DE), A
  INC L
  INC E
  .endm
  LD A, L
  ADD 32
  LD L, A
  RET

; ########################################
; ##                                    ##
; ## Scrolltext without horizontal bars ##
; ##                                    ##
; ########################################

; Parameters/return:
; ABC: ignored/clobbered
; DE: destination address
; HL: source address

; ****************************************
; ** Vertical bars at positions 0 and 1 **
; ****************************************

TextHVBar01:
  LD BC, $1810
  .rept 4
  .rept 2
  LD A, (HL)
  OR B
  LD (DE), A
  INC L
  INC E
  .endm
  .rept 6
  LD A, (HL)
  OR C
  LD (DE), A
  INC L
  INC E
  .endm
  .endm
  LD A, L
  ADD 32
  LD L, A
  RET

; ****************************************
; ** Vertical bars at positions 1 and 2 **
; ****************************************

TextHVBar12:
  LD BC, $1810
  .rept 4
  LD A, (HL)
  OR C
  LD (DE), A
  INC L
  INC E
  .rept 2
  LD A, (HL)
  OR B
  LD (DE), A
  INC L
  INC E
  .endm
  .rept 5
  LD A, (HL)
  OR C
  LD (DE), A
  INC L
  INC E
  .endm
  .endm
  LD A, L
  ADD 32
  LD L, A
  RET

; ****************************************
; ** Vertical bars at positions 2 and 3 **
; ****************************************

TextHVBar23:
  LD BC, $1810
  .rept 4
  .rept 2
  LD A, (HL)
  OR C
  LD (DE), A
  INC L
  INC E
  .endm
  .rept 2
  LD A, (HL)
  OR B
  LD (DE), A
  INC L
  INC E
  .endm
  .rept 4
  LD A, (HL)
  OR C
  LD (DE), A
  INC L
  INC E
  .endm
  .endm
  LD A, L
  ADD 32
  LD L, A
  RET

; ****************************************
; ** Vertical bars at positions 3 and 4 **
; ****************************************

TextHVBar34:
  LD BC, $1810
  .rept 4
  .rept 3
  LD A, (HL)
  OR C
  LD (DE), A
  INC L
  INC E
  .endm
  .rept 2
  LD A, (HL)
  OR B
  LD (DE), A
  INC L
  INC E
  .endm
  .rept 3
  LD A, (HL)
  OR C
  LD (DE), A
  INC L
  INC E
  .endm
  .endm
  LD A, L
  ADD 32
  LD L, A
  RET

; ****************************************
; ** Vertical bars at positions 4 and 5 **
; ****************************************

TextHVBar45:
  LD BC, $1810
  .rept 4
  .rept 4
  LD A, (HL)
  OR C
  LD (DE), A
  INC L
  INC E
  .endm
  .rept 2
  LD A, (HL)
  OR B
  LD (DE), A
  INC L
  INC E
  .endm
  .rept 2
  LD A, (HL)
  OR C
  LD (DE), A
  INC L
  INC E
  .endm
  .endm
  LD A, L
  ADD 32
  LD L, A
  RET

; ****************************************
; ** Vertical bars at positions 5 and 6 **
; ****************************************

TextHVBar56:
  LD BC, $1810
  .rept 4
  .rept 5
  LD A, (HL)
  OR C
  LD (DE), A
  INC L
  INC E
  .endm
  .rept 2
  LD A, (HL)
  OR B
  LD (DE), A
  INC L
  INC E
  .endm
  LD A, (HL)
  OR C
  LD (DE), A
  INC L
  INC E
  .endm
  LD A, L
  ADD 32
  LD L, A
  RET

; ****************************************
; ** Vertical bars at positions 6 and 7 **
; ****************************************

TextHVBar67:
  LD BC, $1810
  .rept 4
  .rept 6
  LD A, (HL)
  OR C
  LD (DE), A
  INC L
  INC E
  .endm
  .rept 2
  LD A, (HL)
  OR B
  LD (DE), A
  INC L
  INC E
  .endm
  .endm
  LD A, L
  ADD 32
  LD L, A
  RET

; ****************************************
; ** Vertical bars at positions 7 and 0 **
; ****************************************

TextHVBar70:
  LD BC, $1810
  .rept 4
  LD A, (HL)
  OR B
  LD (DE), A
  INC L
  INC E
  .rept 6
  LD A, (HL)
  OR C
  LD (DE), A
  INC L
  INC E
  .endm
  LD A, (HL)
  OR B
  LD (DE), A
  INC L
  INC E
  .endm
  LD A, L
  ADD 32
  LD L, A
  RET

; ##########################
; ##                      ##
; ## Mid-text page switch ##
; ##                      ##
; ##########################

TextNextPage:
  INC H
  RET


  DrawTextList:
  .dw TextVBar01, TextHVBar01
  .dw TextVBar12, TextHVBar12
  .dw TextVBar23, TextHVBar23
  .dw TextVBar34, TextHVBar34
  .dw TextVBar45, TextHVBar45
  .dw TextVBar56, TextHVBar56
  .dw TextVBar67, TextHVBar67
  .dw TextVBar70, TextHVBar70

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

  .org $ed00
SpriteWilly:
  .db %00111100
  .db %00111100
  .db %01111110
  .db %00101100
  .db %01111100
  .db %00111100
  .db %00011000
  .db %00111100

  .db %01110110
  .db %01110110
  .db %01110110
  .db %01101110
  .db %00111100
  .db %00011000
  .db %00011000
  .db %00111000


  .db %00000011
  .db %00000011
  .db %00000111
  .db %00000010
  .db %00000111
  .db %00000011
  .db %00000001
  .db %00000011

  .db %00000111
  .db %00001111
  .db %00011111
  .db %00011011
  .db %00000111
  .db %00010110
  .db %00011100
  .db %00001100

  .db %11000000
  .db %11000000
  .db %11100000
  .db %11000000
  .db %11000000
  .db %11000000
  .db %10000000
  .db %11000000

  .db %11100000
  .db %11110000
  .db %11111000
  .db %11011000
  .db %11000000
  .db %11100000
  .db %00110000
  .db %01110000

  .org $ee00
Logo:
  .rept 16
  .db $20, $20, $00, $00, $00, $20, $20, $00
  .endm
  .rept 8
  .db $20, $20, $20, $00, $20, $20, $20, $00
  .endm
  .rept 8
  .db $20, $20, $20, $20, $20, $20, $20, $00
  .endm
  .rept 8
  .db $20, $20, $00, $20, $00, $20, $20, $00
  .endm
  .rept 24
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

vbars_x:
	.ds	1

text_x:
	.ds	1
