#!/bin/sh
# Copyright 2024 Jean-Baptiste M. "JBQ" "Djaybee" Queru
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# As an added restriction, if you make the program available for
# third parties to use on hardware you own (or co-own, lease, rent,
# or otherwise control,) such as public gaming cabinets (whether or
# not in a gaming arcade, whether or not coin-operated or otherwise
# for a fee,) the conditions of section 13 will apply even if no
# network is involved.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.
#
# SPDX-License-Identifier: AGPL-3.0-or-later

##################################################
##                                              ##
## Build the tape image used during development ##
##                                              ##
##################################################

mkdir -p out/obj
mkdir -p out/tap

# Tokenize BASIC loader, autostart at line 1
zmakebas -a 1 -n MB\'s\ ZX124 -o out/obj/loader.tap loader.bas

# Prepare the loader screen
dd if=/dev/random of=out/obj/splash.bin bs=256 count=27
bin2tap out/obj/splash.bin out/obj/splash.tap -a 0x4000

# Assemble the actual code
zasm --opcodes --labels --cycles mbzx124.asm -o out/obj/mbzx124.bin

# Package the machine code into a tap image
bin2tap out/obj/mbzx124.bin out/obj/code.tap -a 0x5dc0

# Put the whole tape image together, loader + binary
cat out/obj/loader.tap out/obj/splash.tap out/obj/code.tap > out/tap/mbzx124.tap

####################################
##                                ##
## Build the distribution package ##
##                                ##
####################################

rm -rf out/mbzx124 out/src out/dist
mkdir -p out/mbzx124
mkdir -p out/src
mkdir -p out/dist

# Put the actual binary in the distribution folder
cp out/tap/mbzx124.tap out/mbzx124

# Put the README and license files in the distribution folder
cp LICENSE LICENSE_ASSETS AGPL_DETAILS.md README.md out/mbzx124

# Bundle the source history in the distribution folder
git bundle create -q out/mbzx124/mbzx124.bundle HEAD main

# Prepare a source code snapshot for folks who don't want to use git
cp $(ls -1 | grep -v ^out\$ | grep -v \\.rom\$) out/src
(cd out && zip -9 -q mbzx124/src.zip src/*)

# Put the final distro together
(cd out && zip -9 -q dist/mbzx124.zip mbzx124/*)
