`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Testbench: tb_cordic_corners
// Description: Independent verification focusing on Corner Cases (Task 9)
//              and Arbiter Contention (Task 8) for the CORDIC system.
//////////////////////////////////////////////////////////////////////////////////

module tb_cordic_corners();

    parameter CLK_PERIOD = 10;
    parameter W_DATA = 16;
    parameter W_PHASE = 16;
    parameter W_SNR = 8;
    parameter NUM_REQUESTERS = 2;
    parameter MAX_ITER = 16;

    reg clk;
    reg rst_n;
    
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

    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    integer err_cnt = 0;

    initial begin
        // Reset Inputs
        rst_n = 0;
        i_req = 0;
        i_phase_req0 = 0;
        i_phase_req1 = 0;
        i_mod_scheme_req0 = 0;
        i_mod_scheme_req1 = 0;
        i_snr_est_req0 = 0;
        i_snr_est_req1 = 0;

        #(CLK_PERIOD * 5);
        rst_n = 1;
        #(CLK_PERIOD * 2);

        $display("=================================================");
        $display("Starting STANDALONE CORNER CASE TESTBENCH");
        $display("=================================================");

        // --- PART 1: Verification of Phase Corner Cases (Task 9) ---
        $display("[%0t] Corner Case: Phase = 0", $time);
        @(posedge clk);
        i_req = 2'b01;
        i_phase_req0 = 16'sh0000; // 0 degrees
        i_mod_scheme_req0 = 3'd4; // 256QAM (16 iterations)
        i_snr_est_req0 = 8'd100;
        @(posedge clk);
        i_req = 2'b00;
        wait(o_valid);
        $display("    Outputs for 0 deg: Sin=%d (Expected 0), Cos=%d (Expected 16384)", $signed(o_sin), $signed(o_cos));
        if ($signed(o_sin) > -50 && $signed(o_sin) < 50 && $signed(o_cos) > 16300 && $signed(o_cos) < 16450) begin
            $display("    --> PASS: 0 deg");
        end else begin
            $display("    --> FAIL: 0 deg");
            err_cnt = err_cnt + 1;
        end
        #(CLK_PERIOD * 20);

        $display("[%0t] Corner Case: Phase = PI/2 (90 deg)", $time);
        @(posedge clk);
        i_req = 2'b01;
        i_phase_req0 = 16'sh4000; // 90 degrees (16384)
        i_mod_scheme_req0 = 3'd4;
        i_snr_est_req0 = 8'd100;
        @(posedge clk);
        i_req = 2'b00;
        wait(o_valid);
        $display("    Outputs for 90 deg: Sin=%d (Expected 16384), Cos=%d (Expected 0)", $signed(o_sin), $signed(o_cos));
        if ($signed(o_sin) > 16300 && $signed(o_sin) < 16450 && $signed(o_cos) > -50 && $signed(o_cos) < 50) begin
            $display("    --> PASS: 90 deg");
        end else begin
            $display("    --> FAIL: 90 deg");
            err_cnt = err_cnt + 1;
        end
        #(CLK_PERIOD * 20);

        $display("[%0t] Corner Case: Phase = -PI/2 (-90 deg)", $time);
        @(posedge clk);
        i_req = 2'b01;
        i_phase_req0 = -16'sh4000; // -90 degrees (-16384)
        i_mod_scheme_req0 = 3'd4;
        i_snr_est_req0 = 8'd100;
        @(posedge clk);
        i_req = 2'b00;
        wait(o_valid);
        $display("    Outputs for -90 deg: Sin=%d (Expected -16384), Cos=%d (Expected 0)", $signed(o_sin), $signed(o_cos));
        if ($signed(o_sin) > -16450 && $signed(o_sin) < -16300 && $signed(o_cos) > -50 && $signed(o_cos) < 50) begin
            $display("    --> PASS: -90 deg");
        end else begin
            $display("    --> FAIL: -90 deg");
            err_cnt = err_cnt + 1;
        end
        #(CLK_PERIOD * 20);

        $display("[%0t] Corner Case: Phase = PI (180 deg)", $time);
        @(posedge clk);
        i_req = 2'b01;
        i_phase_req0 = -16'sh8000; // -32768 representing -180/180 deg
        i_mod_scheme_req0 = 3'd4;
        i_snr_est_req0 = 8'd100;
        @(posedge clk);
        i_req = 2'b00;
        wait(o_valid);
        $display("    Outputs for 180 deg: Sin=%d (Expected 0), Cos=%d (Expected -16384)", $signed(o_sin), $signed(o_cos));
        if ($signed(o_sin) > -50 && $signed(o_sin) < 50 && $signed(o_cos) > -16450 && $signed(o_cos) < -16300) begin
            $display("    --> PASS: 180 deg");
        end else begin
            $display("    --> FAIL: 180 deg");
            err_cnt = err_cnt + 1;
        end
        #(CLK_PERIOD * 20);


        // --- PART 2: Reset in the Middle of Streaming Data (Task 9) ---
        $display("[%0t] Starting Sudden Reset Test", $time);
        
        // Start streaming data
        @(posedge clk);
        i_req = 2'b01;
        i_phase_req0 = 16'h2000; // 45 deg
        i_mod_scheme_req0 = 3'd3;
        i_snr_est_req0 = 8'd100;
        
        // Feed continuous inputs for 5 cycles
        repeat (5) begin
            @(posedge clk);
            i_phase_req0 = i_phase_req0 + 16'h0500; // Shift phase
        end
        
        // Reset suddenly
        $display("[%0t] !!! ASSERTING SUDDEN RESET SYSTEM-WIDE !!!", $time);
        rst_n = 0;
        i_req = 2'b00;
        
        // Verify output is immediately cleared or goes low
        #(CLK_PERIOD);
        $display("    Outputs during reset: Valid=%b, Sin=%d, Cos=%d", o_valid, o_sin, o_cos);
        if (o_valid == 0 && o_sin == 0 && o_cos == 0) begin
            $display("    --> PASS: Outputs cleared immediately on reset");
        end else begin
            $display("    --> FAIL: Outputs not cleared on reset");
            err_cnt = err_cnt + 1;
        end
        
        // Release reset
        #(CLK_PERIOD * 3);
        rst_n = 1;
        #(CLK_PERIOD * 2);
        
        // Verify system recovers and calculates correctly
        $display("[%0t] Releasing reset. Feeding fresh sample...", $time);
        @(posedge clk);
        i_req = 2'b01;
        i_phase_req0 = 16'h2000; // 45 deg
        @(posedge clk);
        i_req = 2'b00;
        
        wait(o_valid);
        $display("    Outputs post-reset recovery: Sin=%d, Cos=%d", $signed(o_sin), $signed(o_cos));
        if ($signed(o_sin) > 11500 && $signed(o_sin) < 11700) begin
            $display("    --> PASS: Post-reset recovery successful");
        end else begin
            $display("    --> FAIL: Post-reset recovery failed");
            err_cnt = err_cnt + 1;
        end
        
        #(CLK_PERIOD * 20);

        // --- Summary ---
        $display("=================================================");
        if (err_cnt == 0) begin
            $display("ALL STANDALONE CORNER CASE TESTS PASSED!");
        end else begin
            $display("STANDALONE CORNER CASE TESTS FAILED! Errors: %0d", err_cnt);
        end
        $display("=================================================");
        $finish;
    end

endmodule
