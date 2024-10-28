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

#################################################
##                                             ##
## Clean things up before starting a new build ##
##                                             ##
#################################################

echo '(*)' cleaning up before build
rm -rf out || exit $?

##################################################
##                                              ##
## Build the tape image used during development ##
##                                              ##
##################################################

echo '(*)' creating build directories
mkdir -p out/obj || exit $?
mkdir -p out/tap || exit $?

# Tokenize BASIC loader, autostart at line 1
echo '(*)' tokenizing BASIC
zmakebas -a 1 -n MB\'s\ ZX124 -o out/obj/loader.tap loader.bas || exit $?

# Assemble the preloader code
echo '(*)' assembling preloader
zasm --opcodes --labels --cycles preload.asm -o out/obj/preload.bin || exit $?

# Package the preloader binary into a tap image
echo '(*)' packaging preloader
bin2tap out/obj/preload.bin out/obj/preload.tap -a 0x5e00 || exit $?

# Prepare the splash screen
echo '(*)' generating splash screen
dd if=/dev/random of=out/obj/splash.bin bs=256 count=24 || exit $?
bin2tap out/obj/splash.bin out/obj/splash.tap -a 0x4000 || exit $?

# Assemble the actual code
echo '(*)' assembling main code
zasm --opcodes --labels --cycles mbzx124.asm -o out/obj/mbzx124.bin || exit $?

# Package the machine code into a tap image
echo '(*)' packaging main code
bin2tap out/obj/mbzx124.bin out/obj/code.tap -a 0x5e00 || exit $?

# Put the whole tape image together, loader + binary
echo '(*)' preparing tape image
cat out/obj/loader.tap out/obj/preload.tap out/obj/splash.tap out/obj/code.tap > out/tap/mbzx124.tap || exit $?

####################################
##                                ##
## Build the distribution package ##
##                                ##
####################################

echo '(*)' preparing distribution directories
mkdir -p out/mbzx124 || exit $?
mkdir -p out/src || exit $?
mkdir -p out/dist || exit $?

# Put the actual binary in the distribution folder
echo '(*)' copying tape image to distribution
cp out/tap/mbzx124.tap out/mbzx124 || exit $?

# Put the README and license files in the distribution folder
echo '(*)' copying readme/license files to distribution
cp LICENSE LICENSE_ASSETS AGPL_DETAILS.md README.md out/mbzx124 || exit $?

# Bundle the source history in the distribution folder
echo '(*)' preparing git bundle
git bundle create -q out/mbzx124/mbzx124.bundle HEAD main || exit $?

# Prepare a source code snapshot for folks who don't want to use git
echo '(*)' copying source snapshot
cp $(ls -1 | grep -v ^out\$) out/src || exit $?
echo '(*)'  zipping source snapshot
(cd out && zip -9 -q mbzx124/src.zip src/*) || exit $?

# Put the final package together
echo '(*)' zipping distribution package
(cd out && zip -9 -q dist/mbzx124.zip mbzx124/*) || exit $?

echo '(*)' FINISHED BUILDING SUCCESSFULLY
