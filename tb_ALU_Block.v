// ============================================================
// Testbench: tb_ALU_Block.v
// DUT      : ALU_Block
//
// Purpose  : Verify that ALU_Block correctly evaluates an
//            equation supplied by Encoder_Block and returns
//            the right answer with proper operator precedence.
//
// Fixed-point scale used by Encoder: 10^6 = 1_000_000
//   So the answer is also in fixed-point (divide by 10^6 for real value).
//   e.g. answer = 3_000_000 means "3.000000"
//
// Operand packing (96-bit, 4 x 24-bit):
//   operand[0*24 +: 24] = first  operand  (left-most)
//   operand[1*24 +: 24] = second operand
//   operand[2*24 +: 24] = third  operand
//   operand[3*24 +: 24] = fourth operand
//
// Operator encoding (6-bit, 3 x 2-bit):
//   2'b00 => '+'    2'b01 => '-'
//   2'b10 => '*'    2'b11 => '/'
//   operator[0*2 +: 2] = between op[0] and op[1]
//   operator[1*2 +: 2] = between op[1] and op[2]
//   operator[2*2 +: 2] = between op[2] and op[3]
//
// Precedence rules implemented in ALU:
//   1. All * and / are resolved first (right-to-left in current code).
//   2. Then + and - are resolved.
// ============================================================

`timescale 1ns / 1ps

module tb_ALU_Block;

    // --------------------------------------------------------
    // Clock period
    // --------------------------------------------------------
    localparam CLK_PERIOD = 10;

    // --------------------------------------------------------
    // DUT I/O
    // --------------------------------------------------------
    reg        clk;
    reg        rst;
    reg [95:0] operand;
    reg [5:0]  operator;
    reg        Equation_Ready;

    wire [31:0] answer;
    wire        error;

    // --------------------------------------------------------
    // Instantiate DUT
    // --------------------------------------------------------
    ALU_Block u_dut (
        .operand       (operand),
        .operator      (operator),
        .Equation_Ready(Equation_Ready),
        .clk           (clk),
        .rst           (rst),
        .answer        (answer),
        .error         (error)
    );

    // --------------------------------------------------------
    // Clock generation
    // --------------------------------------------------------
    initial clk = 0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    // --------------------------------------------------------
    // Unified Task for User to add test cases easily
    // --------------------------------------------------------
    task check_case;
        input [95:0] in_operand;
        input [5:0]  in_operator;
        input [31:0] expected_answer;
        input        expected_error;
        input [80*8-1:0] test_name;
        begin
            $display("\n[%0t] %0s", $time, test_name);
            
            // 1. Apply Reset for a clean state
            rst            = 1'b0;
            operand        = 96'd0;
            operator       = 6'd0;
            Equation_Ready = 1'b0;
            repeat(4) @(posedge clk); #1;
            rst = 1'b1;
            @(posedge clk); #1;

            // 2. Load inputs and trigger
            Equation_Ready = 1'b0;
            operand        = in_operand;
            operator       = in_operator;
            @(posedge clk); #1;
            Equation_Ready = 1'b1;   // rising edge triggers ALU
            @(posedge clk); #1;
            
            // 3. Wait for result (give it enough cycles)
            repeat(40) @(posedge clk); #1;
            
            // 4. Compare and Print
            $display("  Actual  : answer=%0d, error=%b", answer, error);
            $display("  Expected: answer=%0d, error=%b", expected_answer, expected_error);
            
            if (error !== expected_error)
                $display("  -> FAIL: error flag mismatch");
            else if (!expected_error && answer !== expected_answer)
                $display("  -> FAIL: answer mismatch");
            else
                $display("  -> PASS");
        end
    endtask

    // --------------------------------------------------------
    // Helper function: pack 4 operands into 96-bit vector
    //   All values already in fixed-point (scaled by 10^6)
    // --------------------------------------------------------
    function [95:0] pack_operands;
        input [23:0] a, b, c, d;
        begin
            pack_operands = {d, c, b, a};
        end
    endfunction

    // --------------------------------------------------------
    // Helper function: pack 3 operators into 6-bit vector
    // --------------------------------------------------------
    function [5:0] pack_operators;
        input [1:0] op0, op1, op2;
        begin
            pack_operators = {op2, op1, op0};
        end
    endfunction

    // --------------------------------------------------------
    // Local parameters for operator codes
    // --------------------------------------------------------
    localparam OP_ADD = 2'b00;
    localparam OP_SUB = 2'b01;
    localparam OP_MUL = 2'b10;
    localparam OP_DIV = 2'b11;
    // Padding (no operator between two unused operands)
    localparam OP_NONE = 2'b00;

    // --------------------------------------------------------
    // Main test sequence
    // --------------------------------------------------------
    initial begin
        $display("==============================================");
        $display("  Testbench: ALU_Block");
        $display("==============================================");

        check_case(
            pack_operands(24'd1_000_000, 24'd2_000_000, 24'd0, 24'd0),
            pack_operators(OP_ADD, OP_NONE, OP_NONE),
            32'd3_000_000, 1'b0, "Addition: 1 + 2 = 3"
        );

        check_case(
            pack_operands(24'd5_000_000, 24'd3_000_000, 24'd0, 24'd0),
            pack_operators(OP_SUB, OP_NONE, OP_NONE),
            32'd2_000_000, 1'b0, "Subtraction: 5 - 3 = 2"
        );

        check_case(
            pack_operands(24'd3, 24'd4, 24'd0, 24'd0),
            pack_operators(OP_MUL, OP_NONE, OP_NONE),
            32'd12, 1'b0, "Multiplication: 3 * 4 = 12 (unscaled raw)"
        );

        check_case(
            pack_operands(24'd12, 24'd4, 24'd0, 24'd0),
            pack_operators(OP_DIV, OP_NONE, OP_NONE),
            32'd3, 1'b0, "Division: 12 / 4 = 3 (unscaled raw)"
        );

        check_case(
            pack_operands(24'd5, 24'd0, 24'd0, 24'd0),
            pack_operators(OP_DIV, OP_NONE, OP_NONE),
            32'd0, 1'b1, "Divide-by-zero error: 5 / 0"
        );

        check_case(
            pack_operands(24'd2, 24'd3, 24'd4, 24'd0),
            pack_operators(OP_ADD, OP_MUL, OP_NONE),
            32'd14, 1'b0, "Precedence: 2 + 3 * 4 = 14"
        );

        check_case(
            pack_operands(24'd10, 24'd3, 24'd2, 24'd0),
            pack_operators(OP_SUB, OP_SUB, OP_NONE),
            32'd5, 1'b0, "Associativity: 10 - 3 - 2 = 5"
        );

        check_case(
            pack_operands(24'd1, 24'd2, 24'd3, 24'd4),
            pack_operators(OP_ADD, OP_ADD, OP_ADD),
            32'd10, 1'b0, "Four operands: 1+2+3+4 = 10"
        );

        $display("\n==============================================");
        $display("  ALU_Block testbench COMPLETE");
        $display("==============================================\n");
        $finish;
    end

    // --------------------------------------------------------
    // Timeout watchdog
    // --------------------------------------------------------
    initial begin
        #500000;
        $display("ERROR: Simulation timeout!");
        $finish;
    end

endmodule
