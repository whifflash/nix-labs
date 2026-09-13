/* Hello world: prove the toolchain, board and console work. */
#include <zephyr/kernel.h>
#include <zephyr/sys/printk.h>

int main(void)
{
	unsigned int n = 0;

	while (1) {
		printk("hello from %s (%u)\n", CONFIG_BOARD_TARGET, n++);
		k_sleep(K_SECONDS(1));
	}

	return 0;
}
