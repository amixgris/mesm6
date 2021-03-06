module top(
    input  wire       CLK_50,
    
    output wire [9:0] LEDR,

    output wire [7:0] HEX0,
    output wire [7:0] HEX1,
    output wire [7:0] HEX2,
    output wire [7:0] HEX3,
    output wire [7:0] HEX4,
    output wire [7:0] HEX5,

    input  wire [9:0] SW,
    input  wire [1:0] KEY,
    
    output wire       TXD,
    input  wire       RXD,

    output wire         VGA_HSYNC,
    output wire         VGA_VSYNC,
    output wire [3:0]   VGA_R,
    output wire [3:0]   VGA_G,
    output wire [3:0]   VGA_B,

    output wire         BUZZER
);

reg [31:0] cnt  = 0;

wire [47:0] idata;

// PLL outputs 10Mhz clock
wire clk;
mesm6_pll pll(.inclk0(CLK_50), .c0(clk));

// Instruction memory signals.
wire        ibus_rd;       // fetch request
wire [14:0] ibus_addr;     // address
wire [47:0] ibus_input;    // instruction word from memory
wire        ibus_done;     // operation completed

// Data memory signals.
wire        dbus_rd;       // read request
wire        dbus_wr;       // write request
wire [14:0] dbus_addr;     // address
wire [47:0] dbus_output;   // data to memory
wire [47:0] dbus_input;    // data from memory
wire        dbus_done;     // operation completed

wire reset = ~KEY[1];
wire irq;

mesm6_core cpu(
    clk,                    // clock on rising edge
    reset,                  // reset on rising edge
    irq,                    // interrupt request

    // Instruction memory bus.
    ibus_rd,                // request instruction fetch
    ibus_addr,              // memory address
    ibus_input,             // instruction word read
    ibus_done,              // memory operation completed

    // Data memory bus.
    dbus_rd,                // request data read
    dbus_wr,                // request data write
    dbus_addr,              // memory address
    dbus_output,            // data written
    dbus_input,             // data read
    dbus_done               // memory operation completed
);

// Instruction memory.
imemory prom(
    clk,                    // clock on rising edge
    ibus_addr,              // memory address
    ibus_rd,                // read request
    ibus_input,             // data from memory
    ibus_done               // operation completed
);


// Data memory.
wire [14:0] mem_addr;
wire        mem_read;
wire        mem_write;
wire        mem_done;
wire [47:0] mem_rdata;
wire [47:0] mem_wdata;

dmemory dram(
    .clk(clk),                    // clock on rising edge
    .i_addr(mem_addr),              // memory address
    .i_read(mem_read),                // read request
    .i_write(mem_write),                // write request
    .i_data(mem_wdata),            // data to memory
    .o_data(mem_rdata),             // data from memory
    .o_done(mem_done)               // operation completed
);

wire [47:0] pic_irq;
wire [14:0] pic_addr;
wire        pic_read;
wire        pic_write;
wire [47:0] pic_rdata;
wire [47:0] pic_wdata;
wire        pic_done;

mesm6_pic pic(
    clk, reset, irq,

    pic_irq,

    pic_addr,
    pic_read,
    pic_write,
    pic_rdata,
    pic_wdata,
    pic_done
);

// GPIO signals
wire        gpio_int;

wire [14:0] gpio_addr;
wire        gpio_read;
wire        gpio_write;
wire [47:0] gpio_rdata;
wire [47:0] gpio_wdata;
wire        gpio_done;

wire  [47:0] gpio_inputs;
wire  [47:0] gpio_outputs;

assign LEDR = gpio_outputs;

assign HEX0 = ~(gpio_outputs[ 7: 0]);
assign HEX1 = ~(gpio_outputs[15: 8]);
assign HEX2 = ~(gpio_outputs[23:16]);
assign HEX3 = ~(gpio_outputs[31:24]);
assign HEX4 = ~(gpio_outputs[39:32]);
assign HEX5 = ~(gpio_outputs[47:40]);

/*assign HEX2 = ~to_hex(dbus_input[3:0]);
assign HEX3 = ~to_hex(dbus_input[7:4]);*/

/*assign HEX4 = ~to_hex(ibus_addr[3:0]);
assign HEX5 = ~to_hex(ibus_addr[7:4]);*/

/*
assign HEX0 = ~to_hex(ibus_addr[ 3: 0]);
assign HEX1 = ~to_hex(ibus_addr[ 7: 4]);
assign HEX2 = ~to_hex(ibus_addr[11: 8]);
assign HEX3 = ~to_hex(ibus_addr[14:12]);
*/

mesm6_debouncer debounce(
    clk,

    SW,
    gpio_inputs
);

mesm6_gpio gpio(
    clk, reset, gpio_int,

    gpio_addr,
    gpio_read,
    gpio_write,
    gpio_rdata,
    gpio_wdata,
    gpio_done,
     
    gpio_inputs,
    gpio_outputs
);

// Timer signals
wire        tim_irq;
wire [14:0] tim_addr;
wire        tim_read;
wire        tim_write;
wire [47:0] tim_rdata;
wire [47:0] tim_wdata;
wire        tim_done;
wire        tim_pwm;

mesm6_timer tim(
    clk, reset, tim_irq,

    tim_addr,
    tim_read, tim_write,
    tim_rdata, tim_wdata,
    tim_done,
    
    tim_pwm
);

assign BUZZER = tim_pwm;

// UART signals
wire        uart_irq;
wire [14:0] uart_addr;
wire        uart_read;
wire        uart_write;
wire [47:0] uart_rdata;
wire [47:0] uart_wdata;
wire        uart_done;


mesm6_uart uart(
    clk, reset, uart_irq,

    // MESM-6 side
    uart_addr,
    uart_read, uart_write,
    uart_rdata, uart_wdata,
    uart_done,

    TXD, RXD
);

// VGA signals
wire        vga_irq;
wire [14:0] vga_addr;
wire        vga_read;
wire        vga_write;
wire [47:0] vga_rdata;
wire [47:0] vga_wdata;
wire        vga_done;

mesm6_vga vga(
    clk, reset, vga_irq,

    // MESM-6 side
    vga_addr,
    vga_read, vga_write,
    vga_rdata, vga_wdata,
    vga_done,

    // VGA pins
    VGA_HSYNC,
    VGA_VSYNC,
    VGA_R,
    VGA_G,
    VGA_B
);


mesm6_mmu mmu(
    dbus_addr,
    dbus_rd, dbus_wr,
    dbus_output, dbus_input,
    dbus_done,

    mem_addr,
    mem_read,  mem_write,
    mem_rdata, mem_wdata,
    mem_done,

    pic_addr,
    pic_read,  pic_write,
    pic_rdata, pic_wdata,
    pic_done,
    pic_irq,

    gpio_addr,
    gpio_read, gpio_write,
    gpio_rdata, gpio_wdata,
    gpio_done,
    gpio_int,

    uart_addr,
    uart_read, uart_write,
    uart_rdata, uart_wdata,
    uart_done,
    uart_irq,

    vga_addr,
    vga_read, vga_write,
    vga_rdata, vga_wdata,
    vga_done,
    vga_irq,

    tim_addr,
    tim_read, tim_write,
    tim_rdata, tim_wdata,
    tim_done,
    tim_irq
);


function [7:0] to_hex(input [3:0] ival);
    begin
        to_hex = ival == 0  ? 8'b00111111 :
                    ival == 1  ? 8'b00000110 :
                    ival == 2  ? 8'b01011011 :
                    ival == 3  ? 8'b01001111 :
                    ival == 4  ? 8'b01100110 :
                    ival == 5  ? 8'b01101101 :
                    ival == 6  ? 8'b01111101 :
                    ival == 7  ? 8'b00000111 :
                    ival == 8  ? 8'b01111111 :
                    ival == 9  ? 8'b01101111 :
                    ival == 10 ? 8'b01110111 :
                    ival == 11 ? 8'b01111100 :
                    ival == 12 ? 8'b00111001 :
                    ival == 13 ? 8'b01011110 :
                    ival == 14 ? 8'b01111001 :
                    ival == 15 ? 8'b01110001 :
                                                 0 ;
    end
endfunction


endmodule
