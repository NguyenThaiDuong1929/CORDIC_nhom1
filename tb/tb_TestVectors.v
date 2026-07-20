`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Testbench: tb_TestVectors
// Description: Reads python-generated test vectors and performs cycle-by-cycle 
//              comparison with RTL outputs using a self-checking FIFO queue.
//////////////////////////////////////////////////////////////////////////////////

module tb_TestVectors();

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
    
    // FIFO to store expected values and input tracking
    reg [W_DATA-1:0] expected_sin_fifo [0:20000];
    reg [W_DATA-1:0] expected_cos_fifo [0:20000];
    reg [W_DATA-1:0] actual_sin_fifo   [0:20000];
    reg [W_DATA-1:0] actual_cos_fifo   [0:20000];
    reg [W_PHASE-1:0] input_phase_fifo [0:20000];
    reg [2:0]         input_mod_fifo   [0:20000];
    reg [W_SNR-1:0]   input_snr_fifo   [0:20000];
    
    integer write_ptr = 0;
    integer read_ptr = 0;
    integer compare_cnt = 0;
    integer mismatch_cnt = 0;
    integer file_id;
    integer status;
    integer timeout_cnt;
    
    // Temporary variables for reading
    reg [15:0] tmp_phase;
    reg [3:0]  tmp_mod;
    reg [7:0]  tmp_snr;
    reg [15:0] tmp_sin;
    reg [15:0] tmp_cos;
    
    // Stimulation process
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
        #(CLK_PERIOD * 5);
        
        // Open file
        // Try multiple paths in case running from different directories
        file_id = $fopen("test_vectors.txt", "r");
        if (file_id == 0) begin
            file_id = $fopen("../../../../../python simulation/test_vectors.txt", "r");
        end
        if (file_id == 0) begin
            file_id = $fopen("../../python simulation/test_vectors.txt", "r");
        end
        if (file_id == 0) begin
            file_id = $fopen("python simulation/test_vectors.txt", "r");
        end
        if (file_id == 0) begin
            $display("ERROR: Could not open test_vectors.txt file!");
            $finish;
        end
        
        $display("=========================================================");
        $display("STARTING CORDIC PYTHON VS VIVADO VECTOR COMPARISON");
        $display("=========================================================");
        
        // Read file line by line and feed to DUT
        while (!$feof(file_id)) begin
            status = $fscanf(file_id, "%x %x %x %x %x\n", tmp_phase, tmp_mod, tmp_snr, tmp_sin, tmp_cos);
            if (status == 5) begin
                @(posedge clk);
                // Assert Request on Requester 0
                i_req = 2'b01;
                i_phase_req0 = tmp_phase;
                i_mod_scheme_req0 = tmp_mod[2:0];
                i_snr_est_req0 = tmp_snr;
                
                // Store expected values and inputs in FIFO
                expected_sin_fifo[write_ptr] = tmp_sin;
                expected_cos_fifo[write_ptr] = tmp_cos;
                input_phase_fifo[write_ptr]  = tmp_phase;
                input_mod_fifo[write_ptr]    = tmp_mod[2:0];
                input_snr_fifo[write_ptr]    = tmp_snr;
                
                write_ptr = write_ptr + 1;
                
                // Wait for grant to ensure request is accepted
                @(negedge clk);
                while (o_grant[0] == 0) begin
                    @(posedge clk);
                    @(negedge clk);
                end
            end
        end
        
        // Clear request
        @(posedge clk);
        i_req = 2'b00;
        $fclose(file_id);
        
        $display("Fed %0d vectors. Waiting for pipeline to flush...", write_ptr);
        
        // Wait until all fed vectors are processed and checked
        // Added timeout protection (max 30,000 cycles) to prevent simulation hang
        timeout_cnt = 0;
        while (read_ptr < write_ptr && timeout_cnt < 30000) begin
            @(posedge clk);
            timeout_cnt = timeout_cnt + 1;
        end
        
        if (timeout_cnt >= 30000) begin
            $display("=========================================================");
            $display("ERROR: Simulation TIMEOUT waiting for pipeline to flush!");
            $display("write_ptr (Vectors Sent)     : %0d", write_ptr);
            $display("read_ptr  (Vectors Received) : %0d", read_ptr);
            $display("=========================================================");
        end
        
        #(CLK_PERIOD * 10);
        
        $display("=========================================================");
        $display("SIMULATION COMPLETE");
        $display("Total Vectors Compared : %0d", compare_cnt);
        $display("Total Mismatches       : %0d", mismatch_cnt);
        if (mismatch_cnt == 0) begin
            $display(">>> SUCCESS: 100%% Match between Python and Vivado RTL! <<<");
        end else begin
            $display(">>> FAILURE: Mismatches found! <<<");
        end
        $display("=========================================================");
        
        // --- SPECIFIC CASES DYNAMIC VERIFICATION ---
        $display("\n=========================================================");
        $display("   SPECIFIC TEST CASES DYNAMIC VERIFICATION (Bit-True)");
        $display("           (Dynamically loaded from test_vectors.txt)");
        $display("=========================================================");

        if (write_ptr >= 1) begin
            $display("Test Case 1: Input Phase = %h, Mod = %0d, SNR = %h (%0d dB)", 
                     input_phase_fifo[0], input_mod_fifo[0], input_snr_fifo[0], input_snr_fifo[0]);
            $display("  Expected (Python)  : Sin = %h, Cos = %h", expected_sin_fifo[0], expected_cos_fifo[0]);
            $display("  Calculated (Vivado): Sin = %h, Cos = %h", actual_sin_fifo[0], actual_cos_fifo[0]);
            if (actual_sin_fifo[0] === expected_sin_fifo[0] && actual_cos_fifo[0] === expected_cos_fifo[0]) begin
                $display("  Matching Status    : SUCCESS (100% Match)");
            end else begin
                $display("  Matching Status    : FAILED");
            end
            $display("---------------------------------------------------------");
        end

        if (write_ptr >= 2) begin
            $display("Test Case 2: Input Phase = %h, Mod = %0d, SNR = %h (%0d dB)", 
                     input_phase_fifo[1], input_mod_fifo[1], input_snr_fifo[1], input_snr_fifo[1]);
            $display("  Expected (Python)  : Sin = %h, Cos = %h", expected_sin_fifo[1], expected_cos_fifo[1]);
            $display("  Calculated (Vivado): Sin = %h, Cos = %h", actual_sin_fifo[1], actual_cos_fifo[1]);
            if (actual_sin_fifo[1] === expected_sin_fifo[1] && actual_cos_fifo[1] === expected_cos_fifo[1]) begin
                $display("  Matching Status    : SUCCESS (100% Match)");
            end else begin
                $display("  Matching Status    : FAILED");
            end
            $display("---------------------------------------------------------");
        end

        $finish;
    end
    
    // Verification process (Self-Checking)
    always @(posedge clk) begin
        if (rst_n && o_valid) begin
            if (read_ptr < write_ptr) begin
                actual_sin_fifo[read_ptr] = o_sin;
                actual_cos_fifo[read_ptr] = o_cos;
                compare_cnt = compare_cnt + 1;
                if ((o_sin !== expected_sin_fifo[read_ptr]) || (o_cos !== expected_cos_fifo[read_ptr])) begin
                    $display("[Error at Vector %0d] Inputs: Phase=%h, Mod=%d, SNR=%d | Expected: Sin=%h, Cos=%h | Got: Sin=%h, Cos=%h",
                             read_ptr, input_phase_fifo[read_ptr], input_mod_fifo[read_ptr], input_snr_fifo[read_ptr],
                             expected_sin_fifo[read_ptr], expected_cos_fifo[read_ptr], o_sin, o_cos);
                    mismatch_cnt = mismatch_cnt + 1;
                end
                read_ptr = read_ptr + 1;
            end
        end
    end

endmodule
