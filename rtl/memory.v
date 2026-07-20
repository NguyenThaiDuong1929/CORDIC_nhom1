`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: cordic_memory
// Description: ROM storing the arctangent values (Twiddle Factor LUT angles).
//////////////////////////////////////////////////////////////////////////////////

module cordic_memory #(
    parameter W_PHASE = 16,
    parameter W_ITER = 5,
    parameter MAX_ITER = 16
)(
    input  wire [W_ITER-1:0]  i_iter_idx,
    output wire [W_PHASE-1:0] o_atan_val
);

    // Fixed-point format for Phase: 
    // Representing -pi to +pi mapping to full range of signed 16 bits (-32768 to +32767).
    // Or we can map 0 to 2*pi as 0 to 65535.
    // Let's assume binary angles where 1.0 = 45 degrees = 2^13 (8192)
    // Here are pre-calculated atan(2^-i) values:
    
    reg [W_PHASE-1:0] lut [0:MAX_ITER-1];
    
    initial begin
        lut[0]  = 16'd8192; // atan(2^-0) = 45 deg
        lut[1]  = 16'd4836; // atan(2^-1) = 26.565 deg
        lut[2]  = 16'd2555; // atan(2^-2) = 14.036 deg
        lut[3]  = 16'd1297; // atan(2^-3) = 7.125 deg
        lut[4]  = 16'd651;  // atan(2^-4) = 3.576 deg
        lut[5]  = 16'd326;  // atan(2^-5) = 1.790 deg
        lut[6]  = 16'd163;  // atan(2^-6) = 0.895 deg
        lut[7]  = 16'd81;   // atan(2^-7) = 0.448 deg
        lut[8]  = 16'd41;   // atan(2^-8) = 0.224 deg
        lut[9]  = 16'd20;   // atan(2^-9) = 0.112 deg
        lut[10] = 16'd10;   // atan(2^-10)= 0.056 deg
        lut[11] = 16'd5;    // atan(2^-11)= 0.028 deg
        lut[12] = 16'd3;    // atan(2^-12)= 0.014 deg
        lut[13] = 16'd1;    // atan(2^-13)= 0.007 deg
        lut[14] = 16'd1;    // atan(2^-14)= 0.003 deg
        lut[15] = 16'd0;    // atan(2^-15)
    end
    
    assign o_atan_val = lut[i_iter_idx];

endmodule
