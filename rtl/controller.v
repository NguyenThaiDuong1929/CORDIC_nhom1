`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: cordic_controller
// Description: Decodes the Modulation Scheme and SNR Estimate to determine the 
//              optimal number of CORDIC iterations needed (Cycle-Accurate).
//////////////////////////////////////////////////////////////////////////////////

module cordic_controller #(
    parameter W_SNR = 8,
    parameter W_ITER = 5,    
    parameter MAX_ITER = 16
)(
    input  wire clk,
    input  wire rst_n,
    
    // Inputs from Arbiter/Top
    input  wire             i_valid,
    input  wire [W_SNR-1:0] i_snr_est,
    input  wire [2:0]       i_mod_scheme,
    
    // Outputs to Datapath
    output reg               o_valid_ctrl,
    output reg  [W_ITER-1:0] o_req_iters,
    output wire              o_pipeline_ctrl 
);

    // Modulation definitions
    localparam MOD_BPSK   = 3'd0;
    localparam MOD_QPSK   = 3'd1;
    localparam MOD_16QAM  = 3'd2;
    localparam MOD_64QAM  = 3'd3;
    localparam MOD_256QAM = 3'd4;
    
    // Thresholds for SNR (Example values)
    localparam SNR_LOW  = 8'd30;
    localparam SNR_MED  = 8'd80;
    
    wire snr_is_low = (i_snr_est < SNR_LOW);
    wire snr_is_med = (i_snr_est >= SNR_LOW && i_snr_est < SNR_MED);
    wire snr_is_hi  = (i_snr_est >= SNR_MED);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            o_valid_ctrl <= 1'b0;
            o_req_iters  <= {W_ITER{1'b0}};
        end else begin
            o_valid_ctrl <= i_valid;
            if (i_valid) begin
                case (i_mod_scheme)
                    MOD_BPSK: begin
                        // Low modulation, doesn't need many iterations
                        if (snr_is_low)      o_req_iters <= 4'd4;
                        else if (snr_is_med) o_req_iters <= 4'd5;
                        else                 o_req_iters <= 4'd6;
                    end
                    MOD_QPSK: begin
                        if (snr_is_low)      o_req_iters <= 4'd6;
                        else if (snr_is_med) o_req_iters <= 4'd7;
                        else                 o_req_iters <= 4'd8;
                    end
                    MOD_16QAM: begin
                        if (snr_is_low)      o_req_iters <= 4'd8;
                        else if (snr_is_med) o_req_iters <= 4'd9;
                        else                 o_req_iters <= 4'd10;
                    end
                    MOD_64QAM: begin
                        if (snr_is_low)      o_req_iters <= 4'd10;
                        else if (snr_is_med) o_req_iters <= 4'd12;
                        else                 o_req_iters <= 4'd14;
                    end
                    MOD_256QAM: begin
                        if (snr_is_low)      o_req_iters <= 4'd12;
                        else if (snr_is_med) o_req_iters <= 4'd14;
                        else                 o_req_iters <= MAX_ITER[W_ITER-1:0];
                    end
                    default: o_req_iters <= MAX_ITER[W_ITER-1:0];
                endcase
            end
        end
    end
    
    assign o_pipeline_ctrl = 1'b0; // Reserved for clock gating

endmodule
