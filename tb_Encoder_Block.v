// ============================================================
// Testbench: tb_Encoder_Block.v
// DUT      : Encoder_Block
//
// Purpose  : Verify that Encoder_Block correctly parses a
//            raw expression buffer (produced by Input_Reader)
//            into structured operands and operators:
//
//              1. Simple integer expression: "1+2"
//              2. Multi-operand expression : "1+2+3"
//              3. Expression with decimal  : "1.5+2"
//              4. Operator precedence check: "2*3+1" (encode only)
//              5. Error detection          : leading operator "+2"
//              6. Reset behaviour
//
// Fixed-point representation used internally:
//   The integer part N is stored as N * 1_000_000 (scale = 10^6).
//   Example: "3" is stored as 3_000_000  (0x2DC6C0)
//            "1.50" is stored as 1_500_000 (0x16E360)
//
// Operand packing (96-bit, 4 x 24-bit):
//   operand[0*24 +: 24] = first  operand
//   operand[1*24 +: 24] = second operand
//   operand[2*24 +: 24] = third  operand
//   operand[3*24 +: 24] = fourth operand
//
// Operator encoding (6-bit, 3 x 2-bit):
//   2'b00 => '+'    2'b01 => '-'
//   2'b10 => '*'    2'b11 => '/'
//   operator[0*2 +: 2] = first  operator (between op0 and op1)
//   operator[1*2 +: 2] = second operator (between op1 and op2)
//   operator[2*2 +: 2] = third  operator (between op2 and op3)
// ============================================================

`timescale 1ns / 1ps

module tb_Encoder_Block;

    // --------------------------------------------------------
    // Character encoding constants
    // --------------------------------------------------------
    localparam CHAR_ADD       = 5'd10;
    localparam CHAR_SUB       = 5'd11;
    localparam CHAR_MUL       = 5'd12;
    localparam CHAR_DIV       = 5'd13;
    localparam CHAR_DOT       = 5'd14;
    localparam CHAR_BACKSPACE = 5'd15;
    localparam CHAR_EQUAL     = 5'd16;

    // --------------------------------------------------------
    // Clock period
    // --------------------------------------------------------
    localparam CLK_PERIOD = 10;

    // --------------------------------------------------------
    // DUT I/O
    // --------------------------------------------------------
    reg         clk;
    reg         rst;
    reg [159:0] expression;
    reg         expression_ready;
    reg [5:0]   expression_len;

    wire [95:0] operand;
    wire [5:0]  operator;
    wire        Equation_Ready;
    wire        error;

    // --------------------------------------------------------
    // Instantiate DUT
    // --------------------------------------------------------
    Encoder_Block u_dut (
        .expression      (expression),
        .expression_ready(expression_ready),
        .expression_len  (expression_len),
        .rst             (rst),
        .clk             (clk),
        .operand         (operand),
        .operator        (operator),
        .Equation_Ready  (Equation_Ready),
        .error           (error)
    );

    // --------------------------------------------------------
    // Clock generation
    // --------------------------------------------------------
    initial clk = 0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    // --------------------------------------------------------
    // Helper task: apply active-low reset
    // --------------------------------------------------------
    task apply_reset;
        begin
            rst              = 1'b0;
            expression       = 160'd0;
            expression_ready = 1'b0;
            expression_len   = 6'd0;
            repeat(4) @(posedge clk);
            #1;
            rst = 1'b1;
            @(posedge clk); #1;
        end
    endtask

    // --------------------------------------------------------
    // Helper task: write a 5-bit character into the 160-bit
    //              expression buffer at a given index.
    //   The module stores only the lower 4 bits of each char.
    // --------------------------------------------------------
    task write_char;
        input [5:0] idx;
        input [4:0] ch;
        begin
            expression[idx*4 +: 4] = ch[3:0];
        end
    endtask

    // --------------------------------------------------------
    // Helper task: trigger Encoder and wait until it finishes
    //   (Equation_Ready or error asserted) or timeout.
    // --------------------------------------------------------
    task trigger_and_wait;
        input [6:0] timeout_cycles;
        integer cyc;
        begin
            expression_ready = 1'b1;
            cyc = 0;
            while (Equation_Ready === 1'b0 && error === 1'b0 && cyc < timeout_cycles) begin
                @(posedge clk); #1;
                cyc = cyc + 1;
            end
            if (cyc >= timeout_cycles)
                $display("  WARNING: Timed out waiting for Encoder to finish");
        end
    endtask

    // --------------------------------------------------------
    // Helper functions for packing expected values
    // --------------------------------------------------------
    function [95:0] pack_operands;
        input [23:0] a, b, c, d;
        begin
            pack_operands = {d, c, b, a};
        end
    endfunction

    function [5:0] pack_operators;
        input [1:0] op0, op1, op2;
        begin
            pack_operators = {op2, op1, op0};
        end
    endfunction

    localparam CHAR_NONE = 5'd31;

    // --------------------------------------------------------
    // Unified Task for User to add test cases easily
    // --------------------------------------------------------
    task check_case;
        input [4:0] c0, c1, c2, c3, c4, c5, c6, c7;
        input [95:0] expected_operand;
        input [5:0]  expected_operator;
        input        expected_ready;
        input        expected_error;
        input [80*8-1:0] test_name;
        begin
            $display("\n[%0t] %0s", $time, test_name);
            
            // 1. Reset
            apply_reset;
            expression = 160'd0;
            expression_len = 0;

            // 2. Load characters
            if (c0 != CHAR_NONE) begin write_char(0, c0); expression_len = 1; end
            if (c1 != CHAR_NONE) begin write_char(1, c1); expression_len = 2; end
            if (c2 != CHAR_NONE) begin write_char(2, c2); expression_len = 3; end
            if (c3 != CHAR_NONE) begin write_char(3, c3); expression_len = 4; end
            if (c4 != CHAR_NONE) begin write_char(4, c4); expression_len = 5; end
            if (c5 != CHAR_NONE) begin write_char(5, c5); expression_len = 6; end
            if (c6 != CHAR_NONE) begin write_char(6, c6); expression_len = 7; end
            if (c7 != CHAR_NONE) begin write_char(7, c7); expression_len = 8; end

            // 3. Trigger and wait
            trigger_and_wait(100);

            // 4. Compare
            $display("  Actual  : ready=%b, error=%b, op=[%0d,%0d,%0d,%0d], opr=[%02b,%02b,%02b]", 
                     Equation_Ready, error,
                     operand[0*24+:24], operand[1*24+:24], operand[2*24+:24], operand[3*24+:24],
                     operator[0*2+:2], operator[1*2+:2], operator[2*2+:2]);
            
            if (error !== expected_error) $display("  -> FAIL: error mismatch");
            else if (Equation_Ready !== expected_ready) $display("  -> FAIL: ready mismatch");
            else if (!expected_error && expected_ready) begin
                if (operand !== expected_operand) $display("  -> FAIL: operand mismatch");
                else if (operator !== expected_operator) $display("  -> FAIL: operator mismatch");
                else $display("  -> PASS");
            end else begin
                $display("  -> PASS");
            end
        end
    endtask

    // --------------------------------------------------------
    // Main test sequence
    // --------------------------------------------------------
    initial begin
        $display("==============================================");
        $display("  Testbench: Encoder_Block");
        $display("==============================================");

        check_case(
            5'd1, CHAR_ADD, 5'd2, CHAR_NONE, CHAR_NONE, CHAR_NONE, CHAR_NONE, CHAR_NONE,
            pack_operands(24'd1_000_000, 24'd2_000_000, 24'd0, 24'd0), pack_operators(2'b00, 2'b00, 2'b00),
            1'b1, 1'b0, "Simple integer addition: 1+2"
        );

        check_case(
            5'd1, CHAR_ADD, 5'd2, CHAR_ADD, 5'd3, CHAR_NONE, CHAR_NONE, CHAR_NONE,
            pack_operands(24'd1_000_000, 24'd2_000_000, 24'd3_000_000, 24'd0), pack_operators(2'b00, 2'b00, 2'b00),
            1'b1, 1'b0, "Three-operand addition: 1+2+3"
        );

        check_case(
            5'd1, CHAR_ADD, 5'd2, CHAR_SUB, 5'd3, CHAR_MUL, 5'd4, CHAR_NONE,
            pack_operands(24'd1_000_000, 24'd2_000_000, 24'd3_000_000, 24'd4_000_000), pack_operators(2'b00, 2'b01, 2'b10),
            1'b1, 1'b0, "Mixed operators encoding: 1+2-3*4"
        );

        check_case(
            5'd1, CHAR_DOT, 5'd5, CHAR_ADD, 5'd2, CHAR_NONE, CHAR_NONE, CHAR_NONE,
            pack_operands(24'd1_500_000, 24'd2_000_000, 24'd0, 24'd0), pack_operators(2'b00, 2'b00, 2'b00),
            1'b1, 1'b0, "Decimal operand: 1.5+2"
        );

        check_case(
            5'd6, CHAR_DIV, 5'd2, CHAR_NONE, CHAR_NONE, CHAR_NONE, CHAR_NONE, CHAR_NONE,
            pack_operands(24'd6_000_000, 24'd2_000_000, 24'd0, 24'd0), pack_operators(2'b11, 2'b00, 2'b00),
            1'b1, 1'b0, "Division operator encoding: 6/2"
        );

        check_case(
            5'd1, CHAR_DOT, CHAR_DOT, 5'd5, CHAR_ADD, 5'd2, CHAR_NONE, CHAR_NONE,
            pack_operands(24'd0, 24'd0, 24'd0, 24'd0), pack_operators(2'b00, 2'b00, 2'b00),
            1'b0, 1'b1, "Error: double decimal point in 1..5+2"
        );

        // --------------------------------------------------------
        $display("\n==============================================");
        $display("  Encoder_Block testbench COMPLETE");
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
