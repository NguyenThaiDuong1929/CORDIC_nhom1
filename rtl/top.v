`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: cordic_top
// Description: Top level wrapper connecting Arbiter, Controller, Datapath, Memory.
//////////////////////////////////////////////////////////////////////////////////

module cordic_top #(
    parameter W_DATA = 16,
    parameter W_PHASE = 16,
    parameter W_SNR = 8,
    parameter NUM_REQUESTERS = 2,
    parameter MAX_ITER = 16,
    parameter W_ITER = 5
)(
    input  wire clk,
    input  wire rst_n,
    
    // Interface from multiple requesters
    input  wire [NUM_REQUESTERS-1:0] i_req,
    input  wire [W_PHASE-1:0]        i_phase_req0,
    input  wire [W_PHASE-1:0]        i_phase_req1,
    input  wire [2:0]                i_mod_scheme_req0,
    input  wire [2:0]                i_mod_scheme_req1,
    input  wire [W_SNR-1:0]          i_snr_est_req0,
    input  wire [W_SNR-1:0]          i_snr_est_req1,
    output wire [NUM_REQUESTERS-1:0] o_grant,
    
    // Outputs
    output wire               o_valid,
    output wire [W_DATA-1:0]  o_sin,
    output wire [W_DATA-1:0]  o_cos
);

    // Internal Arbiter signals
    wire               arb_valid;
    wire [W_PHASE-1:0] arb_phase;
    wire [2:0]         arb_mod_scheme;
    wire [W_SNR-1:0]   arb_snr_est;

    // Instantiate Arbiter
    cordic_arbiter #(
        .NUM_REQUESTERS(NUM_REQUESTERS),
        .W_PHASE(W_PHASE),
        .W_SNR(W_SNR)
    ) u_arbiter (
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
        .o_valid(arb_valid),
        .o_phase(arb_phase),
        .o_mod_scheme(arb_mod_scheme),
        .o_snr_est(arb_snr_est)
    );

    // Internal Signals
    wire              ctrl_valid_out;
    wire [W_ITER-1:0] req_iters;
    wire              pipeline_ctrl;
    wire [W_ITER-1:0] mem_idx;
    wire [W_PHASE-1:0] atan_val;

    // Delay arb_phase by 1 clock cycle to align with controller latency
    reg [W_PHASE-1:0] arb_phase_delayed;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            arb_phase_delayed <= {W_PHASE{1'b0}};
        end else begin
            arb_phase_delayed <= arb_phase;
        end
    end

    // Instantiate Controller
    cordic_controller #(
        .W_SNR(W_SNR),
        .W_ITER(W_ITER),
        .MAX_ITER(MAX_ITER)
    ) u_controller (
        .clk(clk),
        .rst_n(rst_n),
        .i_valid(arb_valid),
        .i_snr_est(arb_snr_est),
        .i_mod_scheme(arb_mod_scheme),
        .o_valid_ctrl(ctrl_valid_out),
        .o_req_iters(req_iters),
        .o_pipeline_ctrl(pipeline_ctrl)
    );

    // Instantiate Memory
    cordic_memory #(
        .W_PHASE(W_PHASE),
        .W_ITER(W_ITER),
        .MAX_ITER(MAX_ITER)
    ) u_memory (
        .i_iter_idx(mem_idx),
        .o_atan_val(atan_val)
    );

    // Instantiate Datapath
    cordic_datapath #(
        .W_DATA(W_DATA),
        .W_PHASE(W_PHASE),
        .W_ITER(W_ITER),
        .MAX_ITER(MAX_ITER)
    ) u_datapath (
        .clk(clk),
        .rst_n(rst_n),
        .i_valid(ctrl_valid_out),
        .i_req_iters(req_iters),
        .i_phase(arb_phase_delayed),
        .o_mem_idx(mem_idx),
        .i_atan_val(atan_val),
        .o_valid(o_valid),
        .o_sin(o_sin),
        .o_cos(o_cos)
    );

endmodule
