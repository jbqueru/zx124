# ZX124

Explorations in ZX Spectrum programming

This is an attempt by Djaybee from the MegaBusters to write
some form of demo for ZX Spectrum. 

# Tooling and build

## Tools used

This code is being developed with the following tools:

* The [`zmakebas` BASIC tokenizer](https://github.com/chris-y/zmakebas)
* The [`zasm` z80 assembler](https://k1.spdns.de/Develop/Projects/zasm/)
* The [`bin2tap` tape image generator](https://github.com/retro-speccy/bin2tap)
* The [`Fuse` ZX Spectrum emulator](https://fuse-emulator.sourceforge.net/)
* The [`ZEsarUX` emulator for ZX Spectrum and other Z80-based machines](https://github.com/chernandezba/zesarux)
* The [`Clock Signal` low-latency multi-machine emulator](https://github.com/TomHarte/CLK)

## Build process

The ZX Spectrum doesn't support binary executables, it boots
into a BASIC interpreter and, from there, can only directly
load and interpret BASIC code.

To get into a binary, the BASIC interpreter first needs to load
the binary in RAM, and then invoke it, which is typically done
by a "loader" BASIC program that is packaged with the actual
binary.

Furthermore, the BASIC interpreter on the ZX Spectrum is always
tokenized, it can't handle ASCII inputs. That means that the BASIC
program, as source code, needs to be processed into its tokenized
form.

On top of that, the ZX Spectrum uses tape as its primary storage
medium, such that we have to deal with tape images.

zmakebas tokenizes BASIC from source code, and outputs directly
a tape image.

zasm assembles our code into a raw binary. bin2tap turns that
binary into a Spectrum tape image.

Tape images can be concatenated (just like real tapes!)

# (Un)important things

## Licensing

The demo in this repository is licensed under the terms of the
[AGPL, version 3](https://www.gnu.org/licenses/agpl-3.0.en.html)
or later, with the following additional restriction: if you make
the program available for third parties to use on hardware you own
(or co-own, lease, rent, or otherwise control,) such as public
gaming cabinets (whether or not in a gaming arcade, whether or not
coin-operated or otherwise for a fee,) the conditions of section 13
will apply even if no network is involved.

As a special exception, the source assets for the demo (images, text,
music, movie files) as well as output from the demo (screenshots,
audio or video recordings) are also optionally licensed under the
[CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/)
License. That exception explicitly does not apply to source code or
object/executable code, only to assets/media files when separated
from the source code or object/executable file.

Licensees of the a whole demo or of the whole repository may apply
the same exception to their modified version, or may decide to
remove that exception entirely.

## Privacy (including GDPR)

None of the code in this project processes any personal data
in any way. It does not collect, record, organize, structure,
store, adapt, alter, retrieve, consult, use, disclose, transmit,
disseminate, align, combine, restrict, erase, or destroy any
personal data.

None of the code in this project identifies natural persons
in any way, directly or indirectly. It does not reference
any name, identification number, location data, online
identifier, or any factors related to the physical, psychological,
genetic, mental, economic, cultural or social identity of
any person.

None of the code in this project evaluates any aspect of
any natural person. It neither analyzes nor predicts performance
at work, economic situation, health, personal preferences,
interests, reliability, behavior, location, and movements.

_Let's be honest, if using a demo on such an old computer,
even emulated, causes significant privacy concerns or in
fact any privacy concerns, the world is coming to an end._

## Security (including CRA)

None of the code in this project involves any direct or indirect
logical or physical data connection to a device or network.

Also, all of the code in this project is provided under a free
and open source license, in a non-commercial manner. It is
developed, maintained, and distributed openly. As of October
2024, no price has been charged for any of the code in this
project, nor have any donations been accepted in connection
with this project. The author has no intention of charging a
price for this code. They also do not intend to accept donations,
but acknowledge that, in extreme situations, donations of
hardware or of access to hardware might facilitate development,
without any intent to make a profit.

_Don't even think of using any code from this project for
anything remotely security-sensitive. That would be awfully
stupid.
In the context of the ZX Sprectrum, there are no security
features in place.
Also, the code is developed in assembly language, which
lacks the modern language features that help security._
