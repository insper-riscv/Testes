// RV32_TEST_KIND: unit
#include "rv32_test.h"

#define UART_BASE      0xC0000000u
#define UART_TX_DATA   (*(volatile unsigned int *)(UART_BASE + 0x00u))
#define UART_STATUS    (*(volatile unsigned int *)(UART_BASE + 0x08u))
#define UART_TX_READY  (1u << 1)
#define UART_TX_IDLE   (1u << 6)

static void uart_wait_tx_ready(void)
{
    while ((UART_STATUS & UART_TX_READY) == 0u) {
    }
}

static void uart_putc(unsigned char value)
{
    uart_wait_tx_ready();
    UART_TX_DATA = value;
}

static void uart_wait_tx_idle(void)
{
    while ((UART_STATUS & UART_TX_IDLE) == 0u) {
    }
}

int main(void)
{
    static const char message[] = "Hello, world!\r\n";

    for (unsigned int i = 0; message[i] != '\0'; ++i) {
        uart_putc((unsigned char)message[i]);
    }

    /* TX_READY indica espaço na FIFO; TX_IDLE confirma o último stop bit. */
    uart_wait_tx_idle();

    RV32_PASS();
}
