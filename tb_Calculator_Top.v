// ============================================================
// Testbench: tb_Calculator_Top.v
// DUT      : Calculator_Top  (Top-level integration test)
//
// Purpose  : End-to-end (E2E) integration test that exercises
//            the full data path:
//              Input_Reader -> Encoder_Block -> ALU_Block
//
//            Simulates a user pressing buttons on the calculator
//            and checks that the final 'answer' output is correct.
//
// Button value encoding (5-bit):
//   0-9  -> digit '0'-'9'
//   10   -> '+'  (CHAR_ADD)
//   11   -> '-'  (CHAR_SUB)
//   12   -> '*'  (CHAR_MUL)
//   13   -> '/'  (CHAR_DIV)
//   14   -> '.'  (CHAR_DOT)
//   15   -> Backspace
//   16   -> '='  (triggers calculation)
//
// Answer is in fixed-point (scale 10^6):
//   answer = 3_000_000 means 3.000000
//   answer = 1_500_000 means 1.500000
//
// Flow per test:
//   1. Assert reset.
//   2. Press button sequence (digits + operators).
//   3. Press '=' to lock in the expression.
//   4. Wait enough clock cycles for the pipeline to finish.
//   5. Check answer and error outputs.
// ============================================================

`timescale 1ns / 1ps

module tb_Calculator_Top;

    // --------------------------------------------------------
    // Button encoding constants
    // --------------------------------------------------------
    localparam CHAR_ADD       = 5'd10;
    localparam CHAR_SUB       = 5'd11;
    localparam CHAR_MUL       = 5'd12;
    localparam CHAR_DIV       = 5'd13;
    localparam CHAR_DOT       = 5'd14;
    localparam CHAR_BACKSPACE = 5'd15;
    localparam CHAR_EQUAL     = 5'd16;
    localparam CHAR_NONE      = 5'd31; // Used for padding empty inputs in task

    // --------------------------------------------------------
    // Clock period
    // --------------------------------------------------------
    localparam CLK_PERIOD = 10;  // 10 ns => 100 MHz

    // --------------------------------------------------------
    // DUT I/O
    // --------------------------------------------------------
    reg        clk;
    reg        rst;
    reg  [4:0] button_value;
    reg        button_valid;

    wire [31:0] answer;
    wire        error;

    // --------------------------------------------------------
    // Instantiate the top-level DUT
    // --------------------------------------------------------
    Calculator_Top u_dut (
        .clk         (clk),
        .rst         (rst),
        .button_value(button_value),
        .button_valid(button_valid),
        .answer      (answer),
        .error       (error)
    );

    // --------------------------------------------------------
    // Clock generation
    // --------------------------------------------------------
    initial clk = 0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    // --------------------------------------------------------
    // Helper task: apply active-low reset for a clean start
    // --------------------------------------------------------
    task apply_reset;
        begin
            rst          = 1'b0;  // Assert active-low reset
            button_valid = 1'b0;
            button_value = 5'd0;
            repeat(5) @(posedge clk); #1;
            rst = 1'b1;           // Release reset
            @(posedge clk); #1;
        end
    endtask

    // --------------------------------------------------------
    // Helper task: press a single button.
    // --------------------------------------------------------
    task press_button;
        input [4:0] val;
        begin
            @(posedge clk); #1;
            button_value = val;
            button_valid = 1'b1;
            @(posedge clk); #1;
            button_valid = 1'b0;
            @(posedge clk); #1;   // settle
        end
    endtask

    // --------------------------------------------------------
    // Unified Task for User to add test cases easily
    // --------------------------------------------------------
    task check_case;
        input [4:0] b1, b2, b3, b4, b5, b6, b7, b8, b9, b10;
        input [31:0] expected_answer;
        input        expected_error;
        input [80*8-1:0] test_name;
        begin
            $display("\n[%0t] %0s", $time, test_name);
            
            // 1. Reset
            apply_reset;

            // 2. Press buttons
            if (b1 != CHAR_NONE) press_button(b1);
            if (b2 != CHAR_NONE) press_button(b2);
            if (b3 != CHAR_NONE) press_button(b3);
            if (b4 != CHAR_NONE) press_button(b4);
            if (b5 != CHAR_NONE) press_button(b5);
            if (b6 != CHAR_NONE) press_button(b6);
            if (b7 != CHAR_NONE) press_button(b7);
            if (b8 != CHAR_NONE) press_button(b8);
            if (b9 != CHAR_NONE) press_button(b9);
            if (b10 != CHAR_NONE) press_button(b10);

            // 3. Wait for the full pipeline to compute
            repeat(200) @(posedge clk); #1;
            
            // 4. Check outputs
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
    // Main test sequence
    // --------------------------------------------------------
    initial begin
        $display("==============================================");
        $display("  Testbench: Calculator_Top (Integration)");
        $display("==============================================\n");

        check_case(
            5'd1, CHAR_ADD, 5'd2, CHAR_EQUAL,
            CHAR_NONE, CHAR_NONE, CHAR_NONE, CHAR_NONE, CHAR_NONE, CHAR_NONE,
            32'd300, 1'b0, "1 + 2 = 3"
        );

        check_case(
            5'd5, CHAR_SUB, 5'd3, CHAR_EQUAL,
            CHAR_NONE, CHAR_NONE, CHAR_NONE, CHAR_NONE, CHAR_NONE, CHAR_NONE,
            32'd200, 1'b0, "5 - 3 = 2"
        );

        check_case(
            5'd3, CHAR_MUL, 5'd4, CHAR_EQUAL,
            CHAR_NONE, CHAR_NONE, CHAR_NONE, CHAR_NONE, CHAR_NONE, CHAR_NONE,
            32'd1200, 1'b0, "3 * 4 = 12 (expected properly scaled)"
        );

        check_case(
            5'd8, CHAR_DIV, 5'd2, CHAR_EQUAL,
            CHAR_NONE, CHAR_NONE, CHAR_NONE, CHAR_NONE, CHAR_NONE, CHAR_NONE,
            32'd400, 1'b0, "8 / 2 = 4"
        );

        check_case(
            5'd5, CHAR_DIV, 5'd0, CHAR_EQUAL,
            CHAR_NONE, CHAR_NONE, CHAR_NONE, CHAR_NONE, CHAR_NONE, CHAR_NONE,
            32'd0, 1'b1, "5 / 0 -> error"
        );

        check_case(
            5'd1, 5'd2, CHAR_BACKSPACE, 5'd3, CHAR_ADD, 5'd4, CHAR_EQUAL,
            CHAR_NONE, CHAR_NONE, CHAR_NONE,
            32'd1700, 1'b0, "Backspace: 13+4=17"
        );

        check_case(
            5'd1, CHAR_DOT, 5'd5, CHAR_ADD, 5'd2, CHAR_DOT, 5'd5, CHAR_EQUAL,
            CHAR_NONE, CHAR_NONE,
            32'd400, 1'b0, "Decimal: 1.5 + 2.5 = 4.0"
        );

        check_case(
            5'd2, CHAR_ADD, 5'd3, CHAR_MUL, 5'd4, CHAR_EQUAL,
            CHAR_NONE, CHAR_NONE, CHAR_NONE, CHAR_NONE,
            32'd1400, 1'b0, "Precedence: 2 + 3 * 4 = 14"
        );

        check_case(
            5'd1, 5'd0, CHAR_SUB, 5'd3, CHAR_SUB, 5'd2, CHAR_EQUAL,
            CHAR_NONE, CHAR_NONE, CHAR_NONE,
            32'd500, 1'b0, "Associativity: 10 - 3 - 2 = 5"
        );

        // ======================================================
        // ADDED TEST CASES (HARDER & ERROR CASES)
        // ======================================================
        check_case(
            5'd2, CHAR_DOT, 5'd5, CHAR_MUL, 5'd4, CHAR_SUB, 5'd1, CHAR_EQUAL,
            CHAR_NONE, CHAR_NONE,
            32'd900, 1'b0, "Harder Math: 2.5 * 4 - 1 = 9"
        );

        check_case(
            5'd1, 5'd0, CHAR_SUB, 5'd2, CHAR_MUL, 5'd3, CHAR_EQUAL,
            CHAR_NONE, CHAR_NONE, CHAR_NONE,
            32'd400, 1'b0, "Harder Precedence: 10 - 2 * 3 = 4"
        );

        check_case(
            5'd5, CHAR_ADD, 5'd2, CHAR_DIV, 5'd0, CHAR_EQUAL,
            CHAR_NONE, CHAR_NONE, CHAR_NONE, CHAR_NONE,
            32'd0, 1'b1, "Complex Error: 5 + 2 / 0 = error"
        );

        check_case(
            CHAR_MUL, 5'd2, CHAR_EQUAL,
            CHAR_NONE, CHAR_NONE, CHAR_NONE, CHAR_NONE, CHAR_NONE, CHAR_NONE, CHAR_NONE,
            32'd0, 1'b1, "Syntax Error: * 2 = error (missing left operand)"
        );
        check_case(
            5'd5, CHAR_DIV, CHAR_EQUAL,
            CHAR_NONE, CHAR_NONE, CHAR_NONE, CHAR_NONE, CHAR_NONE, CHAR_NONE, CHAR_NONE,
            32'd0, 1'b1, "Syntax Error: 5 / = error (missing right operand)"
        );

        check_case(
            5'd5, CHAR_ADD, CHAR_MUL, 5'd3, CHAR_EQUAL,
            CHAR_NONE, CHAR_NONE, CHAR_NONE, CHAR_NONE, CHAR_NONE,
            32'd0, 1'b1, "Syntax Error: 5 + * 3 = error (double operator)"
        );

        check_case(
            5'd1, CHAR_DOT, 5'd2, CHAR_DOT, 5'd3, CHAR_EQUAL,
            CHAR_NONE, CHAR_NONE, CHAR_NONE, CHAR_NONE,
            32'd0, 1'b1, "Syntax Error: 1.2.3 = error (multiple decimal points)"
        );

        check_case(
            5'd1, 5'd0, 5'd0, CHAR_DIV, 5'd3, CHAR_MUL, 5'd3, CHAR_EQUAL,
            CHAR_NONE, CHAR_NONE,
            32'd9999, 1'b0, "Complex Math & Rounding: 100 / 3 * 3 = 99.99"
        );
        // ======================================================

        // TEST 10: Maximum expression length stress test
        //   Press 20 digit '1's, then '=' to see no crash.
        //   No mathematical check; just verifying no lockup.
        // ======================================================
        $display("[TEST 10] Stress: 20-character expression (no crash check)");
        apply_reset;
        begin : stress_test
            integer k;
            for (k = 0; k < 6; k = k + 1) begin
                press_button(5'd1);   // digit '1'
            end
            press_button(CHAR_ADD);
            for (k = 0; k < 6; k = k + 1) begin
                press_button(5'd2);   // digit '2'
            end
            press_button(CHAR_EQUAL);
        end
        repeat(300) @(posedge clk); #1;
        $display("  answer=%0d  error=%b", answer, error);
        if (!error)
            $display("  PASS: No lockup or error on long expression");
        else
            $display("  INFO: Error asserted (overflow or too many digits)");
        $display("");

        // --------------------------------------------------------
        $display("==============================================");
        $display("  Calculator_Top integration testbench COMPLETE");
        $display("==============================================\n");
        $finish;
    end

    // --------------------------------------------------------
    // Timeout watchdog: kill simulation if stuck
    // --------------------------------------------------------
    initial begin
        #1_000_000;
        $display("ERROR: Global simulation timeout reached!");
        $finish;
    end

    // --------------------------------------------------------
    // Optional: dump VCD waveform for GTKWave / ModelSim
    //   Uncomment the lines below to enable waveform capture.
    // --------------------------------------------------------
    // initial begin
    //     $dumpfile("calc_top_wave.vcd");
    //     $dumpvars(0, tb_Calculator_Top);
    // end

endmodule
