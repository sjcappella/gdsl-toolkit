/*
 * opcodes.h
 *
 *  Created on: Apr 29, 2013
 *      Author: jucs
 */

#ifndef X86_OPCODES_H_
#define X86_OPCODES_H_

#include <stdint.h>

struct opcode_table {
	size_t *offsets;
	size_t offsets_length;

	uint8_t *opcodes;
};

extern struct opcode_table *x86_opcodes_opcode_table_build();
extern void x86_opcodes_opcode_table_free(struct opcode_table *table);

#endif /* X86_OPCODES_H_ */
