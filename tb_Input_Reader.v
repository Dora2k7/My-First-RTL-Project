// ============================================================
// Testbench: tb_Input_Reader.v
// DUT      : Input_Reader
//
// Purpose  : Verify that the Input_Reader module correctly:
//              1. Stores digit / operator characters into the buffer.
//              2. Asserts 'expression_ready' when '=' is pressed.
//              3. Performs backspace (delete last character).
//              4. Ignores all input once expression_ready is HIGH.
//              5. Resets to a clean state on active-low rst.
//
// Encoding (button_value, 5-bit):
//   0-9  -> digit characters
//   10   -> '+'  (CHAR_ADD)
//   11   -> '-'  (CHAR_SUB)
//   12   -> '*'  (CHAR_MUL)
//   13   -> '/'  (CHAR_DIV)
//   14   -> '.'  (CHAR_DOT)
//   15   -> Backspace (CHAR_BACKSPACE)
//   16   -> '='  (CHAR_EQUAL)
// ============================================================

`timescale 1ns / 1ps

module tb_Input_Reader;

    // --------------------------------------------------------
    // Character encoding constants (mirror calculator_defs.vh)
    // --------------------------------------------------------
    localparam CHAR_ADD       = 5'd10;
    localparam CHAR_SUB       = 5'd11;
    localparam CHAR_MUL       = 5'd12;
    localparam CHAR_DIV       = 5'd13;
    localparam CHAR_DOT       = 5'd14;
    localparam CHAR_BACKSPACE = 5'd15;
    localparam CHAR_EQUAL     = 5'd16;

    // --------------------------------------------------------
    // Clock period definition
    // --------------------------------------------------------
    localparam CLK_PERIOD = 10; // 10 ns => 100 MHz

    // --------------------------------------------------------
    // DUT I/O declarations
    // --------------------------------------------------------
    reg        clk;
    reg        rst;
    reg  [4:0] button_value;
    reg        button_valid;

    wire [159:0] expression_buffer;
    wire         expression_ready;
    wire [5:0]   count;

    // --------------------------------------------------------
    // Instantiate the Device Under Test (DUT)
    // --------------------------------------------------------
    Input_Reader u_dut (
        .clk              (clk),
        .rst              (rst),
        .button_value     (button_value),
        .button_valid     (button_valid),
        .expression_buffer(expression_buffer),
        .expression_ready (expression_ready),
        .count            (count)
    );

    // --------------------------------------------------------
    // Clock generation: toggle every half-period
    // --------------------------------------------------------
    initial clk = 0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    // --------------------------------------------------------
    // Helper task: press a single button for one clock cycle.
    //   - Drives button_value & button_valid HIGH for one cycle.
    //   - Deasserts button_valid immediately after.
    //   - Waits one extra cycle for output to settle.
    // --------------------------------------------------------
    task press_button;
        input [4:0] val;
        begin
            @(posedge clk); #1;   // align to just after rising edge
            button_value = val;
            button_valid = 1'b1;
            @(posedge clk); #1;   // DUT latches the value
            button_valid = 1'b0;
            @(posedge clk); #1;   // allow one cycle for outputs to settle
        end
    endtask

    // --------------------------------------------------------
    // Helper task: apply asynchronous active-low reset
    // --------------------------------------------------------
    task apply_reset;
        begin
            rst = 1'b0;           // Assert reset (active-low)
            button_valid = 1'b0;
            button_value = 5'd0;
            repeat(3) @(posedge clk); // Hold for 3 cycles
            #1;
            rst = 1'b1;           // Release reset
            @(posedge clk); #1;
        end
    endtask

    // --------------------------------------------------------
    // Helper task: print current state for debugging
    // --------------------------------------------------------
    task print_state;
        input [80*8-1:0] label;
        begin
            $display("[%0t] %0s | count=%0d | ready=%b | buf[0]=%0d buf[1]=%0d buf[2]=%0d",
                     $time, label, count, expression_ready,
                     expression_buffer[0*4 +: 4],
                     expression_buffer[1*4 +: 4],
                     expression_buffer[2*4 +: 4]);
        end
    endtask

    localparam CHAR_NONE = 5'd31;

    function [159:0] pack_buffer;
        input [3:0] c0, c1, c2, c3, c4, c5, c6, c7;
        begin
            pack_buffer = 160'd0;
            pack_buffer[0*4+:4] = c0;
            pack_buffer[1*4+:4] = c1;
            pack_buffer[2*4+:4] = c2;
            pack_buffer[3*4+:4] = c3;
            pack_buffer[4*4+:4] = c4;
            pack_buffer[5*4+:4] = c5;
            pack_buffer[6*4+:4] = c6;
            pack_buffer[7*4+:4] = c7;
        end
    endfunction

    // --------------------------------------------------------
    // Unified Task for User to add test cases easily
    // --------------------------------------------------------
    task check_case;
        input [4:0] b0, b1, b2, b3, b4, b5, b6, b7;
        input [159:0] expected_buffer;
        input [5:0]   expected_count;
        input         expected_ready;
        input [80*8-1:0] test_name;
        begin
            $display("\n[%0t] %0s", $time, test_name);
            apply_reset;
            if (b0 != CHAR_NONE) press_button(b0);
            if (b1 != CHAR_NONE) press_button(b1);
            if (b2 != CHAR_NONE) press_button(b2);
            if (b3 != CHAR_NONE) press_button(b3);
            if (b4 != CHAR_NONE) press_button(b4);
            if (b5 != CHAR_NONE) press_button(b5);
            if (b6 != CHAR_NONE) press_button(b6);
            if (b7 != CHAR_NONE) press_button(b7);

            $display("  Actual  : count=%0d, ready=%b", count, expression_ready);
            $display("  Expected: count=%0d, ready=%b", expected_count, expected_ready);
            
            if (count !== expected_count) 
                $display("  -> FAIL: count mismatch");
            else if (expression_ready !== expected_ready) 
                $display("  -> FAIL: ready mismatch");
            else if (expression_buffer !== expected_buffer) 
                $display("  -> FAIL: buffer mismatch");
            else 
                $display("  -> PASS");
        end
    endtask

    // --------------------------------------------------------
    // Main test sequence
    // --------------------------------------------------------
    initial begin
        $display("==============================================");
        $display("  Testbench: Input_Reader");
        $display("==============================================");

        // --- Initialise all inputs ---
        rst          = 1'b1;
        button_value = 5'd0;
        button_valid = 1'b0;

        check_case(
            CHAR_NONE, CHAR_NONE, CHAR_NONE, CHAR_NONE, CHAR_NONE, CHAR_NONE, CHAR_NONE, CHAR_NONE,
            160'd0, 6'd0, 1'b0, "Reset behaviour"
        );

        check_case(
            5'd1, 5'd2, 5'd3, CHAR_NONE, CHAR_NONE, CHAR_NONE, CHAR_NONE, CHAR_NONE,
            pack_buffer(4'd1, 4'd2, 4'd3, 4'd0, 4'd0, 4'd0, 4'd0, 4'd0), 6'd3, 1'b0, "Storing digits 1, 2, 3"
        );

        check_case(
            CHAR_ADD, CHAR_NONE, CHAR_NONE, CHAR_NONE, CHAR_NONE, CHAR_NONE, CHAR_NONE, CHAR_NONE,
            pack_buffer(CHAR_ADD[3:0], 4'd0, 4'd0, 4'd0, 4'd0, 4'd0, 4'd0, 4'd0), 6'd1, 1'b0, "Pressing operator '+'"
        );

        check_case(
            5'd1, 5'd2, CHAR_BACKSPACE, CHAR_NONE, CHAR_NONE, CHAR_NONE, CHAR_NONE, CHAR_NONE,
            pack_buffer(4'd1, 4'd0, 4'd0, 4'd0, 4'd0, 4'd0, 4'd0, 4'd0), 6'd1, 1'b0, "Backspace removes last character"
        );

        check_case(
            CHAR_BACKSPACE, CHAR_NONE, CHAR_NONE, CHAR_NONE, CHAR_NONE, CHAR_NONE, CHAR_NONE, CHAR_NONE,
            160'd0, 6'd0, 1'b0, "Backspace on empty buffer does nothing"
        );

        check_case(
            5'd5, CHAR_ADD, 5'd3, CHAR_EQUAL, CHAR_NONE, CHAR_NONE, CHAR_NONE, CHAR_NONE,
            pack_buffer(4'd5, CHAR_ADD[3:0], 4'd3, 4'd0, 4'd0, 4'd0, 4'd0, 4'd0), 6'd3, 1'b1, "expression_ready on '='"
        );

        check_case(
            5'd5, CHAR_EQUAL, 5'd9, CHAR_NONE, CHAR_NONE, CHAR_NONE, CHAR_NONE, CHAR_NONE,
            pack_buffer(4'd5, 4'd0, 4'd0, 4'd0, 4'd0, 4'd0, 4'd0, 4'd0), 6'd1, 1'b1, "Input ignored when expression_ready=1"
        );

        // --------------------------------------------------------
        $display("\n==============================================");
        $display("  Input_Reader testbench COMPLETE");
        $display("==============================================\n");
        $finish;
    end

    // --------------------------------------------------------
    // Timeout watchdog: abort simulation if stuck
    // --------------------------------------------------------
    initial begin
        #100000;
        $display("ERROR: Simulation timeout!");
        $finish;
    end

endmodule
