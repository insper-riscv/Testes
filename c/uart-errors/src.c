// RV32_TEST_KIND: unit
#include "rv32_test.h"

#define UART_BASE      0xC0000000u
#define UART_TX_DATA   (*(volatile unsigned int *)(UART_BASE + 0x00u))
#define UART_RX_DATA   (*(volatile unsigned int *)(UART_BASE + 0x04u))
#define UART_STATUS    (*(volatile unsigned int *)(UART_BASE + 0x08u))

#define UART_RX_VALID   (1u << 0)
#define UART_TX_READY   (1u << 1)
#define UART_RX_OVERRUN (1u << 2)
#define UART_TX_DROPPED (1u << 3)
#define UART_RX_FULL    (1u << 4)
#define UART_TX_IDLE    (1u << 6)
#define UART_RX_LEVEL_SHIFT 8u
#define UART_TX_LEVEL_SHIFT 16u
#define UART_LEVEL_MASK 0xFFu
#define UART_ERROR_MASK (UART_RX_OVERRUN | UART_TX_DROPPED)

#define FIFO_DEPTH          16u
#define TX_ACCEPTED_COUNT   (FIFO_DEPTH + 1u)
#define BURST_BYTE_COUNT    32u

static void require(int condition)
{
    if (!condition) {
        RV32_FAIL();
    }
}

static unsigned int uart_rx_level(unsigned int status)
{
    return (status >> UART_RX_LEVEL_SHIFT) & UART_LEVEL_MASK;
}

static unsigned int uart_tx_level(unsigned int status)
{
    return (status >> UART_TX_LEVEL_SHIFT) & UART_LEVEL_MASK;
}

static void uart_wait_tx_ready(void)
{
    while ((UART_STATUS & UART_TX_READY) == 0u) {
    }
}

static void uart_wait_tx_idle(void)
{
    while ((UART_STATUS & UART_TX_IDLE) == 0u) {
    }
}

static void uart_putc(unsigned char value)
{
    uart_wait_tx_ready();
    UART_TX_DATA = value;
}

static unsigned char uart_getc(void)
{
    while ((UART_STATUS & UART_RX_VALID) == 0u) {
    }

    return (unsigned char)(UART_RX_DATA & 0xFFu);
}

int main(void)
{
    unsigned int status;

    /* Start from a known sticky-error state and empty queues. */
    UART_STATUS = UART_ERROR_MASK;
    status = UART_STATUS;
    require((status & UART_ERROR_MASK) == 0u);
    require((status & UART_TX_IDLE) != 0u);
    require(uart_rx_level(status) == 0u);
    require(uart_tx_level(status) == 0u);

    /*
     * The first byte enters the physical transmitter and the next 16 fill the
     * TX FIFO. The following 'X' must be rejected without disturbing the 17
     * accepted bytes ('A' through 'Q').
     */
    for (unsigned int index = 0; index < TX_ACCEPTED_COUNT; ++index) {
        UART_TX_DATA = (unsigned int)((unsigned char)('A' + index));
    }
    UART_TX_DATA = (unsigned int)'X';

    status = UART_STATUS;
    require((status & UART_TX_READY) == 0u);
    require((status & UART_TX_DROPPED) != 0u);
    require(uart_tx_level(status) == FIFO_DEPTH);

    UART_STATUS = UART_TX_DROPPED;
    require((UART_STATUS & UART_TX_DROPPED) == 0u);
    uart_wait_tx_idle();

    /* Tell the host to send 17 bytes without software consuming RX_DATA. */
    uart_putc((unsigned char)'R');
    uart_wait_tx_idle();

    while ((UART_STATUS & UART_RX_OVERRUN) == 0u) {
    }

    status = UART_STATUS;
    require((status & UART_RX_VALID) != 0u);
    require((status & UART_RX_FULL) != 0u);
    require((status & UART_RX_OVERRUN) != 0u);
    require(uart_rx_level(status) == FIFO_DEPTH);

    /* RX keeps the first 16 queued bytes and drops only the 17th byte. */
    for (unsigned int index = 0; index < FIFO_DEPTH; ++index) {
        require((unsigned int)uart_getc() == index);
    }

    status = UART_STATUS;
    require((status & UART_RX_VALID) == 0u);
    require((status & UART_RX_OVERRUN) != 0u);
    require(uart_rx_level(status) == 0u);

    UART_STATUS = UART_RX_OVERRUN;
    require((UART_STATUS & UART_ERROR_MASK) == 0u);

    /* Acknowledge recovery; the host then sends the normal wrap-around burst. */
    uart_putc((unsigned char)'O');
    uart_wait_tx_idle();

    for (unsigned int index = 0; index < BURST_BYTE_COUNT; ++index) {
        uart_putc(uart_getc());
    }
    uart_wait_tx_idle();
    require((UART_STATUS & UART_ERROR_MASK) == 0u);

    uart_putc((unsigned char)'P');
    uart_wait_tx_idle();
    RV32_PASS();
}
