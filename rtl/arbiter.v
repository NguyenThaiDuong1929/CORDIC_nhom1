`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: cordic_arbiter
// Description: Manages access to the CORDIC datapath when multiple requesters 
//              (e.g., multiple FFT cores) demand twiddle factors simultaneously.
//              Uses a simple priority or round-robin scheme.
//////////////////////////////////////////////////////////////////////////////////

module cordic_arbiter #(
    parameter NUM_REQUESTERS = 2,
    parameter W_PHASE = 16,
    parameter W_SNR = 8
)(
    input  wire clk,
    input  wire rst_n,
    
    // Interface with Requesters (Example for 2 requesters)
    input  wire [NUM_REQUESTERS-1:0] i_req,
    input  wire [W_PHASE-1:0]        i_phase_req0,
    input  wire [W_PHASE-1:0]        i_phase_req1,
    input  wire [2:0]                i_mod_scheme_req0,
    input  wire [2:0]                i_mod_scheme_req1,
    input  wire [W_SNR-1:0]          i_snr_est_req0,
    input  wire [W_SNR-1:0]          i_snr_est_req1,
    output wire [NUM_REQUESTERS-1:0] o_grant,
    
    // Interface to Controller / Datapath
    output wire               o_valid,
    output wire [W_PHASE-1:0] o_phase,
    output wire [2:0]         o_mod_scheme,
    output wire [W_SNR-1:0]   o_snr_est
);

    // Priority pointer register (0 for req0, 1 for req1)
    reg pri;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pri <= 1'b0;
        end else begin
            if (|o_grant) begin
                pri <= ~o_grant[1]; // Toggle priority to ensure fairness
            end
        end
    end

    // Combinational routing logic
    reg [NUM_REQUESTERS-1:0] r_grant;
    reg                      r_valid;
    reg [W_PHASE-1:0]        r_phase;
    reg [2:0]                r_mod_scheme;
    reg [W_SNR-1:0]          r_snr_est;

    always @(*) begin
        r_grant      = {NUM_REQUESTERS{1'b0}};
        r_valid      = 1'b0;
        r_phase      = {W_PHASE{1'b0}};
        r_mod_scheme = 3'd0;
        r_snr_est    = {W_SNR{1'b0}};

        if (pri == 1'b0) begin
            if (i_req[0]) begin
                r_grant[0]   = 1'b1;
                r_valid      = 1'b1;
                r_phase      = i_phase_req0;
                r_mod_scheme = i_mod_scheme_req0;
                r_snr_est    = i_snr_est_req0;
            end else if (i_req[1]) begin
                r_grant[1]   = 1'b1;
                r_valid      = 1'b1;
                r_phase      = i_phase_req1;
                r_mod_scheme = i_mod_scheme_req1;
                r_snr_est    = i_snr_est_req1;
            end
        end else begin
            if (i_req[1]) begin
                r_grant[1]   = 1'b1;
                r_valid      = 1'b1;
                r_phase      = i_phase_req1;
                r_mod_scheme = i_mod_scheme_req1;
                r_snr_est    = i_snr_est_req1;
            end else if (i_req[0]) begin
                r_grant[0]   = 1'b1;
                r_valid      = 1'b1;
                r_phase      = i_phase_req0;
                r_mod_scheme = i_mod_scheme_req0;
                r_snr_est    = i_snr_est_req0;
            end
        end
    end

    assign o_grant      = r_grant;
    assign o_valid      = r_valid;
    assign o_phase      = r_phase;
    assign o_mod_scheme = r_mod_scheme;
    assign o_snr_est    = r_snr_est;


endmodule
