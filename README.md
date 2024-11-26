# ZX124

Explorations in ZX Spectrum programming

This is an attempt by Djaybee from the MegaBusters to write
some form of demo for ZX Spectrum. 

# Architecture

## Separation into files

There's a loader file, `loader.bas`, written in BASIC, which
then loads binary files, in order:

`preload.asm` clears the screen and sets up the screen attributes
before loading the splash screen. The attributes are set first
such that the splash screen is loaded directly with the right colors.

`splash.bin` is the splash screen itself, directly in the format of
the framebuffer bitmap.

`mbzx124.asm` is the main code, loaded after the splash screen.

# Tooling and build

## Tools used

This code is being developed with the following tools:

* At build time:
	+ The [`zmakebas` BASIC tokenizer](https://github.com/chris-y/zmakebas)
	+ The [`zasm` z80 assembler](https://k1.spdns.de/Develop/Projects/zasm/)
	+ The [`bin2tap` tape image generator](https://github.com/retro-speccy/bin2tap)
* To run the code:
	+ The [`Fuse` ZX Spectrum emulator](https://fuse-emulator.sourceforge.net/)
	+ The [`ZEsarUX` emulator for ZX Spectrum and other Z80-based
		machines](https://github.com/chernandezba/zesarux)
	+ The [`Clock Signal` low-latency multi-machine
		emulator](https://github.com/TomHarte/CLK)
* As a development environment:
	+ [Linux Mint](https://linuxmint.com/)
	+ The [`Kate` text editor](https://kate-editor.org/)

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

## Privacy

This code doesn't have any privacy implications, and has been
written without any thought about the privacy implications
that might arise from any changes made to it.

_Let's be honest, if using a demo on such an old computer,
even emulated, causes significant privacy concerns or in
fact any privacy concerns, the world is coming to an end._

### Specific privacy aspects for GDPR (EU 2016/679)

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

_Don't use this code where GDPR might come into scope.
Seriously. Don't. Just don't.

## Security

Generally speaking, the code in this project is inappropriate
for any application where security is a concern of any kind.

_Don't even think of using any code from this project for
anything remotely security-sensitive. That would be awfully
stupid._

_In the context of the Sinclair ZX Spectrum, the hardware
is far too primitive to support any notion of security at
the assembly level, and assembly as a language is as far
from being secure by default as can be._

### Specific security aspects for CRA (EU 2022/454)

None of the code in this project involves any direct or indirect
logical or physical data connection to a device or network.

Also, all of the code in this project is provided under a free
and open source license, in a non-commercial manner. It is
developed, maintained, and distributed openly. As of November
2024, no price has been charged for any of the code in this
project, nor have any donations been accepted in connection
with this project. The author has no intention of charging a
price for this code. They also do not intend to accept donations,
but acknowledge that, in extreme situations, donations of
hardware or of access to hardware might facilitate development,
without any intent to make a profit.

_This code is intended to be used in isolated environments.
If you build a connected product from this code, the security
implications are on you. You've been warned._

### Specific security aspects for NIS2 (EU 2022/2555)

The intended use for this code is not a critical application.
This project has been developed without any attention to the
practices mandated by NIS2 for critical applications.
It is not appropriate as-is for any critical application, and,
by its very nature, no amount of paying and auditing will
ever make it reach a point where it is appropriate.
The author will immediately dismiss any request to reach the
standards set by NIS2.

_Don't even think about it. Seriously. I'm not kidding. If you
are even considering using this code or any similar code for any
critical project, you should expect to get fired.
I cannot understate how grossly inappropriate this code is for
anything that might actually matter._
