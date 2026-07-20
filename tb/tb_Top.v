`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Testbench: tb_cordic_top
// Description: Verifies the multi-requester adaptive CORDIC system,
//              including Round-Robin Arbiter, Quadrant Mapping, and timing logic.
//////////////////////////////////////////////////////////////////////////////////

module tb_Top();

    // Parameters
    parameter CLK_PERIOD = 10;
    parameter W_DATA = 16;
    parameter W_PHASE = 16;
    parameter W_SNR = 8;
    parameter NUM_REQUESTERS = 2;
    parameter MAX_ITER = 16;
    
    // Signals
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
    
    integer error_cnt = 0;

    // Test sequences
    initial begin
        // Init inputs
        rst_n = 0;
        i_req = 2'b00;
        i_phase_req0 = 0;
        i_phase_req1 = 0;
        i_mod_scheme_req0 = 0;
        i_mod_scheme_req1 = 0;
        i_snr_est_req0 = 0;
        i_snr_est_req1 = 0;
        
        // Reset
        #(CLK_PERIOD * 5);
        rst_n = 1;
        #(CLK_PERIOD * 2);
        
        // --- Test 1: Basic functionality (45 degrees on Requester 0) ---
        $display("[%0t] Starting Test 1: Basic Setup (Req0 = 45 deg)", $time);
        @(posedge clk);
        i_req = 2'b01;
        i_phase_req0 = 16'h2000; // 45 degrees
        i_mod_scheme_req0 = 3'd3; // 64QAM
        i_snr_est_req0 = 8'd100;
        @(posedge clk);
        i_req = 2'b00;
        
        // Wait for output
        wait(o_valid);
        $display("[%0t] Test 1 Output: Sin=%d, Cos=%d", $time, $signed(o_sin), $signed(o_cos));
        
        // Check Test 1 (Expected ~ 11585 for 45 deg)
        if ($signed(o_sin) > 11500 && $signed(o_sin) < 11700 && 
            $signed(o_cos) > 11500 && $signed(o_cos) < 11700) begin
            $display("    --> Test 1: CHECK PASSED");
        end else begin
            $display("    --> Test 1: CHECK FAILED. Expected ~11585");
            error_cnt = error_cnt + 1;
        end
        @(posedge clk);
        #(CLK_PERIOD * 20); // Flush pipeline

        // --- Test 2: Quadrant Mapping (135 degrees & -120 degrees) ---
        $display("[%0t] Starting Test 2: Quadrant Mapping (Q2 & Q3)", $time);
        
        // Case 2a: 135 degrees (Quadrant 2)
        @(posedge clk);
        i_req = 2'b01;
        i_phase_req0 = 16'h6000; // 135 degrees
        i_mod_scheme_req0 = 3'd4; // 256QAM (16 iterations)
        i_snr_est_req0 = 8'd100;
        @(posedge clk);
        i_req = 2'b00;
        
        wait(o_valid);
        $display("[%0t] 135 deg Output: Sin=%d, Cos=%d", $time, $signed(o_sin), $signed(o_cos));
        // Sin(135) = 0.707 (~11585), Cos(135) = -0.707 (~-11585)
        if ($signed(o_sin) > 11500 && $signed(o_sin) < 11700 && 
            $signed(o_cos) > -11700 && $signed(o_cos) < -11500) begin
            $display("    --> Test 2a (135 deg): CHECK PASSED");
        end else begin
            $display("    --> Test 2a (135 deg): CHECK FAILED");
            error_cnt = error_cnt + 1;
        end
        
        #(CLK_PERIOD * 20); // Flush pipeline

        // Case 2b: -120 degrees (Quadrant 3)
        @(posedge clk);
        i_req = 2'b01;
        i_phase_req0 = -16'sd21845; // -120 degrees (65536 * -120 / 360)
        i_mod_scheme_req0 = 3'd4;
        i_snr_est_req0 = 8'd100;
        @(posedge clk);
        i_req = 2'b00;
        
        wait(o_valid);
        $display("[%0t] -120 deg Output: Sin=%d, Cos=%d", $time, $signed(o_sin), $signed(o_cos));
        // Sin(-120) = -0.866 (~-14189), Cos(-120) = -0.5 (~-8192)
        if ($signed(o_sin) > -14300 && $signed(o_sin) < -14000 && 
            $signed(o_cos) > -8300 && $signed(o_cos) < -8000) begin
            $display("    --> Test 2b (-120 deg): CHECK PASSED");
        end else begin
            $display("    --> Test 2b (-120 deg): CHECK FAILED");
            error_cnt = error_cnt + 1;
        end

        #(CLK_PERIOD * 20); // Flush pipeline

        // Reset to clear priority state for independent Test 3
        rst_n = 0;
        i_req = 2'b00;
        i_phase_req0 = 0;
        i_phase_req1 = 0;
        i_mod_scheme_req0 = 0;
        i_mod_scheme_req1 = 0;
        i_snr_est_req0 = 0;
        i_snr_est_req1 = 0;
        #(CLK_PERIOD * 3);
        rst_n = 1;
        #(CLK_PERIOD * 2);

        // --- Test 3: Arbiter Contention (Req0 and Req1 request simultaneously) ---
        $display("[%0t] Starting Test 3: Arbiter Contention (Req0 & Req1 active)", $time);
        
        @(posedge clk);
        i_req = 2'b11; // Both request
        
        // Req 0: 45 deg, QPSK, SNR=100 (8 iterations)
        i_phase_req0 = 16'h2000;
        i_mod_scheme_req0 = 3'd1;
        i_snr_est_req0 = 8'd100;
        
        // Req 1: -45 deg, QPSK, SNR=100 (8 iterations)
        i_phase_req1 = -16'h2000;
        i_mod_scheme_req1 = 3'd1;
        i_snr_est_req1 = 8'd100;
        
        // Expect grant to go to Req 0 first (since priority starts at 0)
        #1; // Wait 1ns for combinational logic settling
        $display("[%0t] Grants: %b (Expected: 01)", $time, o_grant);
        if (o_grant == 2'b01) begin
            $display("    --> Test 3a (Grant Req0): CHECK PASSED");
        end else begin
            $display("    --> Test 3a (Grant Req0): CHECK FAILED");
            error_cnt = error_cnt + 1;
        end
        
        // Keep both requests active, expect next cycle to grant Req 1 (due to priority toggle)
        @(posedge clk);
        #1; // Wait 1ns for combinational logic settling
        $display("[%0t] Grants: %b (Expected: 10)", $time, o_grant);
        if (o_grant == 2'b10) begin
            $display("    --> Test 3b (Grant Req1): CHECK PASSED");
        end else begin
            $display("    --> Test 3b (Grant Req1): CHECK FAILED");
            error_cnt = error_cnt + 1;
        end
        
        i_req = 2'b00;
        #(CLK_PERIOD * 30); // Wait for pipeline flush
        
        $display("-----------------------------------------");
        if (error_cnt == 0) begin
            $display("Simulation PASSED! Total Errors: 0");
        end else begin
            $display("Simulation FAILED! Total Errors: %0d", error_cnt);
        end
        $display("-----------------------------------------");
        
        $display("[%0t] Simulation Finished", $time);
        $finish;
    end

endmodule
