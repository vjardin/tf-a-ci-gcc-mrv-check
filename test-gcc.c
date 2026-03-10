/*
 * Reproducer for GCC -Warray-bounds= false positive on low MMIO addresses.
 * Mimics mv-ddr-marvell ddr3_training_leveling.c + TF-A mmio.h pattern.
 *
 * See test-gcc-array.sh for build/test commands.
 */

#include <stdint.h>

/* From TF-A include/lib/mmio.h */
static inline uint32_t mmio_read_32(uintptr_t addr)
{
	return *(volatile uint32_t *)addr;
}

static inline uint64_t mmio_read_64(uintptr_t addr)
{
	return *(volatile uint64_t *)addr;
}

/* From mv-ddr-marvell ddr3_training_leveling.c:1747 */
#define TEST_ADDR	0x8

#ifdef TEST_VOLATILE_FIX

/* FIXED: volatile prevents GCC from constant-folding the address,
 * so it can no longer infer "likely at address zero" */
uint32_t mv_ddr_rl_dqs_burst(int is_64bit)
{
	volatile uintptr_t test_addr = TEST_ADDR;

	if (is_64bit)
		return (uint32_t)mmio_read_64(test_addr);
	else
		return mmio_read_32(test_addr);
}

#else

/* BROKEN: GCC constant-propagates 0x8 into mmio_read, triggering
 * -Werror=array-bounds= ("source object is likely at address zero") */
uint32_t mv_ddr_rl_dqs_burst(int is_64bit)
{
	uintptr_t test_addr = TEST_ADDR;

	if (is_64bit)
		return (uint32_t)mmio_read_64(test_addr);
	else
		return mmio_read_32(test_addr);
}

#endif
