//
// MESM-6: MESM-6 Interrupt controller testbench.
//
// Copyright (c) 2019 Evgeniy Khaluev
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//
`timescale 1ns / 1ps
`default_nettype none
`include "mesm6_defines.sv"

// register addresses
`define PIC_IFS    'o7
`define PIC_IFSSET 'o6
`define PIC_IFSCLR 'o5
`define PIC_IEC    'o4
`define PIC_IECSET 'o3
`define PIC_IECCLR 'o2
`define PIC_ISR    'o0

module testbench_pic();

reg clk, reset;
wire interrupt;

reg [47:0] dev_irq; // irq req's from devices

reg [14:0] pic_addr;
reg pic_read, pic_write;
wire pic_done;

wire [47:0] pic_rdata;
reg  [47:0] pic_wdata;

mesm6_pic pic(
    clk, reset, interrupt,

    dev_irq,

    pic_addr,
    pic_read, pic_write,
    pic_rdata, pic_wdata,
    pic_done
);

initial begin
    $display("Reseting PIC...");
    $monitor("    (%0t) IFS = %o, IEC = %o, ISR = %2d, RDATA = %o",
        $time, pic.IFS, pic.IEC, pic.ISR, pic.pic_rdata);
    $dumpfile("output_pic.vcd");
    $dumpvars();
    clk = 0;

    // Hardware reset.
    reset = 1;
    pic_addr = 0;
    pic_read = 0;
    pic_write = 0;
    pic_wdata = '0;
    dev_irq = '0;
    #10 $display("Reset done.");
    reset = 0;

    // Write zero to IFS.
    #10 $display("Reseting IFS...");
    pic_addr  = `PIC_IFS;
    pic_wdata = '0;
    pic_write = 1;
    wait(pic_done);
    pic_write = 0;
    if (pic.IFS != '0) begin
        $display("FATAL: IFS is not reset.");
        $finish;
    end

    // Activate irq10 request.
    // Check IFS value.
    // No interrupt is expected, as IEC is still zero.
    #10 $display("Set IRQ 10...");
    dev_irq = 1'b1 << 9;
    #10 $display("Reading IFS...");
    pic_addr = `PIC_IFS;
    pic_read = 1;
    wait(pic_done);
    pic_read = 0;
    $display("RDATA: %o", pic_rdata);
    if (pic_rdata == '0) begin
        $display("FATAL: IFS is not changed.");
        $finish;
    end
    if (!interrupt)
        $display("OK: Interrupt is not asserted");
    else begin
        $display("FATAL: Interrupt is asserted!");
        $finish;
    end

    // Enable irq10 in IEC.
    // Expecting a global interrupt request.
    #10 $display("Enabling IRQ 10 in IEC...");
    pic_addr  = `PIC_IEC;
    pic_wdata = 1'b1 << 9;
    pic_write = 1;
    wait(pic_done);
    pic_write = 0;
    #10;
    if (interrupt)
        $display("OK: Interrupt is asserted.");
    else begin
        $display("FATAL: Interrupt is not asserted!");
        $finish;
    end

    // Use IFSSET to activate irq20.
    // Check ISR is nonzero.
    #10 $display("Enabling IRQ 20 with IFSSET...");
    pic_addr = `PIC_IFSSET;
    pic_wdata = 1'b1 << 19;
    pic_write = 1;
    wait(pic_done);
    pic_write = 0;
    #10 $display("Reading ISR value...");
    pic_addr = `PIC_ISR;
    pic_read = 1;
    wait(pic_done);
    pic_read = 0;
    $display("RDATA (ISR): %0d", pic_rdata);
    if (pic_rdata != 39) begin
        $display("FATAL: ISR is not 39!");
        $finish;
    end

    // Use IECCLR to disable irq10.
    // The global interrupt request should deassert.
    #10 $display("Disabling IRQ 10 with IECCLR...");
    pic_addr = `PIC_IECCLR;
    pic_wdata = 1'b1 << 9;
    pic_write = 1;
    wait(pic_done);
    pic_write = 0;
    #10;
    if (!interrupt)
        $display("OK: Interrupt is not asserted");
    else begin
        $display("FATAL: Interrupt is asserted!");
        $finish;
    end
    #10 $display("Reading ISR value...");
    pic_addr = `PIC_ISR;
    pic_read = 1;
    wait(pic_done);
    pic_read = 0;
    $display("RDATA (ISR): %0d", pic_rdata);
    if (pic_rdata != 0) begin
        $display("FATAL: ISR is not 0!");
        $finish;
    end

    // Enable ireq20 via IECSET.
    // Check the global interrupt request is asserted.
    // Check ISR value.
    #10 $display("Enabling IRQ 20 with IECSET...");
    pic_addr = `PIC_IECSET;
    pic_wdata = 1'b1 << 19;
    pic_write = 1;
    wait(pic_done);
    pic_write = 0;
    #10;
    if (interrupt)
        $display("OK: Interrupt is asserted.");
    else begin
        $display("FATAL: Interrupt is not asserted!");
        $finish;
    end
    #10 $display("Reading ISR value...");
    pic_addr = `PIC_ISR;
    pic_read = 1;
    wait(pic_done);
    pic_read = 0;
    $display("RDATA (ISR): %0d", pic_rdata);
    if (pic_rdata != 29) begin
        $display("FATAL: ISR is not 29!");
        $finish;
    end

    // Deactivate ireq20 via IFSCLR.
    // Check the global interrupt request is deasserted.
    // Check ISR is zero.
    #10 $display("Clearing IRQ 20 with IFSCLR...");
    pic_addr = `PIC_IFSCLR;
    pic_wdata = 1'b1 << 19;
    pic_write = 1;
    wait(pic_done);
    pic_write = 0;
    #10;
    if (!interrupt)
        $display("OK: Interrupt is not asserted");
    else begin
        $display("FATAL: Interrupt is asserted!");
        $finish;
    end
    #10 $display("Reading ISR value...");
    pic_addr = `PIC_ISR;
    pic_read = 1;
    wait(pic_done);
    pic_read = 0;
    $display("RDATA (ISR): %0d", pic_rdata);
    if (pic_rdata != 0) begin
        $display("FATAL: ISR is not 0!");
        $finish;
    end

    $display("\n----- Test PASS -----");
    $finish;
end

always begin
    #2 clk = ~clk;
end

endmodule
