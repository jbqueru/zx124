/*
 * Copyright 2024 Jean-Baptiste M. "JBQ" "Djaybee" Queru
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as
 *  published by the Free Software Foundation, either version 3 of the
 * License, or (at your option) any later version.
 *
 * As an added restriction, if you make the program available for
 * third parties to use on hardware you own (or co-own, lease, rent,
 * or otherwise control,) such as public gaming cabinets (whether or
 * not in a gaming arcade, whether or not coin-operated or otherwise
 * for a fee,) the conditions of section 13 will apply even if no
 * network is involved.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program. If not, see <https://www.gnu.org/licenses/>.
 */

// SPDX-License-Identifier: AGPL-3.0-or-later

#include <stdio.h>
#include <math.h>

unsigned char regdump[1792 * 14];

void main() {
	FILE* inputfile = fopen("AREGDUMP.BIN", "rb");
	fread(regdump, 1, 1792 * 14, inputfile);

	for (int i = 0; i < 1792 * 14; i += 14) {
		int v;

		v = regdump[i + 1] * 256 + regdump[i + 2];
		v = v * 1.77345 / 2.0053 + 0.5;
		if (v > 65535) v = 65535;
		regdump[i + 1] = v >> 8;
		regdump[i + 2] = v & 255;

		v = regdump[i + 7];
		v = v * 1.77345 / 2.0053 + 0.5;
		if (v > 31) v = 31;
		regdump[i + 7] = v;

		v = regdump[i + 8] * 256 + regdump[i + 9];
		v = v * 1.77345 / 2.0053 + 0.5;
		if (v > 4095) v = 4095;
		regdump[i + 8] = v >> 8;
		regdump[i + 9] = v & 255;

		v = regdump[i + 10] * 256 + regdump[i + 11];
		v = v * 1.77345 / 2.0053 + 0.5;
		if (v > 4095) v = 4095;
		regdump[i + 10] = v >> 8;
		regdump[i + 11] = v & 255;

		v = regdump[i + 12] * 256 + regdump[i + 13];
		v = v * 1.77345 / 2.0053 + 0.5;
		if (v > 4095) v = 4095;
		regdump[i + 12] = v >> 8;
		regdump[i + 13] = v & 255;
	}

	FILE* outputfile = fopen("out/inc/zxregdump.bin", "wb");
	fwrite(regdump, 1, 1792 * 14, outputfile);
	fclose(outputfile);
}
