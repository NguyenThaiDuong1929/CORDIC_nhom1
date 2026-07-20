`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: cordic_datapath
// Description: Fully unrolled 16-stage CORDIC pipeline for 1 data/cycle throughput.
//              Supports cycle-accurate dynamic termination (bypass) to save power.
//////////////////////////////////////////////////////////////////////////////////

module cordic_datapath #(
    parameter W_DATA = 16,
    parameter W_PHASE = 16,
    parameter W_ITER = 5,
    parameter MAX_ITER = 16
)(
    input  wire clk,
    input  wire rst_n,
    
    // Control inputs
    input  wire              i_valid,
    input  wire [W_ITER-1:0] i_req_iters,
    
    // Data inputs
    input  wire [W_PHASE-1:0] i_phase,
    
    // Memory Interface (Unused in unrolled architecture, kept for compatibility)
    output wire [W_ITER-1:0] o_mem_idx,
    input  wire [W_PHASE-1:0] i_atan_val,
    
    // Outputs
    output reg               o_valid,
    output reg  [W_DATA-1:0] o_sin,
    output reg  [W_DATA-1:0] o_cos
);

    // Initial scale factor for CORDIC (Product of cos(atan(2^-i))) ~ 0.60725
    // Scaled by 2^14 = 9949
    localparam signed [W_DATA-1:0] K_FACTOR = 16'd9949;

    // Arctan LUT (hardcoded for unrolled pipeline)
    wire [W_PHASE-1:0] atan_lut [0:15];
    assign atan_lut[0]  = 16'd8192; assign atan_lut[1]  = 16'd4836;
    assign atan_lut[2]  = 16'd2555; assign atan_lut[3]  = 16'd1297;
    assign atan_lut[4]  = 16'd651;  assign atan_lut[5]  = 16'd326;
    assign atan_lut[6]  = 16'd163;  assign atan_lut[7]  = 16'd81;
    assign atan_lut[8]  = 16'd41;   assign atan_lut[9]  = 16'd20;
    assign atan_lut[10] = 16'd10;   assign atan_lut[11] = 16'd5;
    assign atan_lut[12] = 16'd3;    assign atan_lut[13] = 16'd1;
    assign atan_lut[14] = 16'd1;    assign atan_lut[15] = 16'd0;

    // Pipeline registers
    reg signed [W_DATA-1:0] x_pipe [0:MAX_ITER];
    reg signed [W_DATA-1:0] y_pipe [0:MAX_ITER];
    reg signed [W_PHASE-1:0] z_pipe [0:MAX_ITER];
    reg [W_ITER-1:0] iters_pipe [0:MAX_ITER];
    reg valid_pipe [0:MAX_ITER];
    reg quad_pipe [0:MAX_ITER];


    integer i;

    // Stage 0: Initial mapping (map angles from -180..180 to -90..90)
    wire signed [W_PHASE-1:0] s_phase = i_phase;
    wire in_q23 = (s_phase > 16'sd16384) || (s_phase < -16'sd16384);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x_pipe[0] <= {W_DATA{1'b0}};
            y_pipe[0] <= {W_DATA{1'b0}};
            z_pipe[0] <= {W_PHASE{1'b0}};
            iters_pipe[0] <= {W_ITER{1'b0}};
            valid_pipe[0] <= 1'b0;
            quad_pipe[0]  <= 1'b0;
        end else begin
            valid_pipe[0] <= i_valid;
            iters_pipe[0] <= i_req_iters;
            x_pipe[0]     <= K_FACTOR;
            y_pipe[0]     <= 16'd0;
            quad_pipe[0]  <= in_q23;
            if (s_phase > 16'sd16384) begin
                z_pipe[0] <= s_phase - 16'sd32768; // Rotate by -180 deg
            end else if (s_phase < -16'sd16384) begin
                z_pipe[0] <= s_phase + 16'sd32768; // Rotate by +180 deg
            end else begin
                z_pipe[0] <= s_phase;
            end
        end
    end


    // Stages 1 to MAX_ITER
    genvar g;
    generate
        for (g = 0; g < MAX_ITER; g = g + 1) begin : CORDIC_STAGES
            wire sign_z = z_pipe[g][W_PHASE-1]; // MSB is sign
            wire active = (g < iters_pipe[g]);  // Check if this stage should compute
            
            wire signed [W_DATA-1:0] x_shifted = x_pipe[g] >>> g;
            wire signed [W_DATA-1:0] y_shifted = y_pipe[g] >>> g;

            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    x_pipe[g+1] <= {W_DATA{1'b0}};
                    y_pipe[g+1] <= {W_DATA{1'b0}};
                    z_pipe[g+1] <= {W_PHASE{1'b0}};
                    iters_pipe[g+1] <= {W_ITER{1'b0}};
                    valid_pipe[g+1] <= 1'b0;
                    quad_pipe[g+1]  <= 1'b0;
                end else begin
                    valid_pipe[g+1] <= valid_pipe[g];
                    
                    // Clock gating: only clock the data registers when there is valid data
                    if (valid_pipe[g]) begin
                        iters_pipe[g+1] <= iters_pipe[g];
                        quad_pipe[g+1]  <= quad_pipe[g];
                        
                        if (active) begin
                            if (!sign_z) begin // z >= 0
                                x_pipe[g+1] <= x_pipe[g] - y_shifted;
                                y_pipe[g+1] <= y_pipe[g] + x_shifted;
                                z_pipe[g+1] <= z_pipe[g] - atan_lut[g];
                            end else begin    // z < 0
                                x_pipe[g+1] <= x_pipe[g] + y_shifted;
                                y_pipe[g+1] <= y_pipe[g] - x_shifted;
                                z_pipe[g+1] <= z_pipe[g] + atan_lut[g];
                            end
                        end else begin
                            // Bypass stage to save dynamic power
                            x_pipe[g+1] <= x_pipe[g];
                            y_pipe[g+1] <= y_pipe[g];
                            z_pipe[g+1] <= z_pipe[g];
                        end
                    end
                end
            end
        end
    endgenerate

    // Output assignment
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            o_valid <= 1'b0;
            o_sin   <= {W_DATA{1'b0}};
            o_cos   <= {W_DATA{1'b0}};
        end else begin
            o_valid <= valid_pipe[MAX_ITER];
            if (valid_pipe[MAX_ITER]) begin
                if (quad_pipe[MAX_ITER]) begin
                    o_sin <= -y_pipe[MAX_ITER];
                    o_cos <= -x_pipe[MAX_ITER];
                end else begin
                    o_sin <= y_pipe[MAX_ITER];
                    o_cos <= x_pipe[MAX_ITER];
                end
            end
        end
    end
    
    assign o_mem_idx = {W_ITER{1'b0}};

endmodule
