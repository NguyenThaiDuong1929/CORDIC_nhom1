`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Testbench: tb_VerifySpecific
// Description: Hardcodes the same two specific test cases as Python to output
//              a direct, clean bit-true match comparison in the Vivado console.
//////////////////////////////////////////////////////////////////////////////////

module tb_VerifySpecific();

    parameter CLK_PERIOD = 10;
    parameter W_DATA = 16;
    parameter W_PHASE = 16;
    parameter W_SNR = 8;
    parameter NUM_REQUESTERS = 2;
    parameter MAX_ITER = 16;

    reg clk;
    reg rst_n;

    // Requester inputs
    reg [NUM_REQUESTERS-1:0] i_req;
    reg [W_PHASE-1:0]        i_phase_req0;
    reg [W_PHASE-1:0]        i_phase_req1;
    reg [2:0]                i_mod_scheme_req0;
    reg [2:0]                i_mod_scheme_req1;
    reg [W_SNR-1:0]          i_snr_est_req0;
    reg [W_SNR-1:0]          i_snr_est_req1;

    wire [NUM_REQUESTERS-1:0] o_grant;
    wire                      o_valid;
    wire [W_DATA-1:0]         o_sin;
    wire [W_DATA-1:0]         o_cos;

    // Instantiate DUT
    cordic_top #(
        .W_DATA(W_DATA),
        .W_PHASE(W_PHASE),
        .W_SNR(W_SNR),
        .NUM_REQUESTERS(NUM_REQUESTERS),
        .MAX_ITER(MAX_ITER)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .i_req(i_req),
        .i_phase_req0(i_phase_req0),
        .i_phase_req1(i_phase_req1),
        .i_mod_scheme_req0(i_mod_scheme_req0),
        .i_mod_scheme_req1(i_mod_scheme_req1),
        .i_snr_est_req0(i_snr_est_req0),
        .i_snr_est_req1(i_snr_est_req1),
        .o_grant(o_grant),
        .o_valid(o_valid),
        .o_sin(o_sin),
        .o_cos(o_cos)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Test sequence
    initial begin
        // Reset Inputs
        rst_n = 0;
        i_req = 2'b00;
        i_phase_req0 = 0;
        i_phase_req1 = 0;
        i_mod_scheme_req0 = 0;
        i_mod_scheme_req1 = 0;
        i_snr_est_req0 = 0;
        i_snr_est_req1 = 0;

        // Reset Pulse
        #(CLK_PERIOD * 5);
        rst_n = 1;
        #(CLK_PERIOD * 5);

        $display("=========================================================");
        $display("   CORDIC Vivado RTL Self-Verification (Bit-True)");
        $display("=========================================================");

        // --- TEST CASE 1 ---
        // Inputs: Phase = 3d53 (86.24 deg), Mod = 1 (QPSK), SNR = 2e (46 dB)
        // Expected: Sin = 3fe0, Cos = 03f3
        @(posedge clk);
        i_req = 2'b01;
        i_phase_req0 = 16'h3d53;
        i_mod_scheme_req0 = 3'd1;
        i_snr_est_req0 = 8'h2e;
        
        @(posedge clk);
        i_req = 2'b00; // Clear request immediately (1-cycle pulse)

        // Wait for output valid
        wait(o_valid);
        $display("Test Case 1: Input Phase = 3d53 (86.24 deg), Mod = QPSK (1), SNR = 2e (46 dB)");
        $display("  Expected (Python)  : Sin = 3fe0, Cos = 03f3");
        $display("  Calculated (Vivado): Sin = %h, Cos = %h", o_sin, o_cos);
        if (o_sin === 16'h3fe0 && o_cos === 16'h03f3) begin
            $display("  Matching Status    : SUCCESS (100% Match)");
        end else begin
            $display("  Matching Status    : FAILED");
        end
        $display("---------------------------------------------------------");

        #(CLK_PERIOD * 20); // Flush pipeline completely

        // --- TEST CASE 2 ---
        // Inputs: Phase = a9d0 (-121.20 deg), Mod = 0 (BPSK), SNR = fe (254 dB)
        // Expected: Sin = c8fc, Cos = df53
        @(posedge clk);
        i_req = 2'b01;
        i_phase_req0 = 16'ha9d0;
        i_mod_scheme_req0 = 3'd0;
        i_snr_est_req0 = 8'hfe;
        
        @(posedge clk);
        i_req = 2'b00; // Clear request immediately (1-cycle pulse)

        // Wait for output valid
        wait(o_valid);
        $display("Test Case 2: Input Phase = a9d0 (-121.20 deg), Mod = BPSK (0), SNR = fe (254 dB)");
        $display("  Expected (Python)  : Sin = c8fc, Cos = df53");
        $display("  Calculated (Vivado): Sin = %h, Cos = %h", o_sin, o_cos);
        if (o_sin === 16'hc8fc && o_cos === 16'hdf53) begin
            $display("  Matching Status    : SUCCESS (100% Match)");
        end else begin
            $display("  Matching Status    : FAILED");
        end
        $display("---------------------------------------------------------");

        #(CLK_PERIOD * 10);
        $finish;
    end

endmodule
