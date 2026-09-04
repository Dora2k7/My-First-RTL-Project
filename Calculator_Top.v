module Calculator_Top (
    input wire clk,
    input wire rst,
    input wire [4:0] button_value,
    input wire button_valid,
    output wire [31:0] answer,
    output wire error
);
`include "calculator_defs.vh"


    // Internal wires for connecting modules
    wire [159:0] expression_buffer;
    wire expression_ready;
    wire [5:0] count;
    
    wire [95:0] operand;
    wire [5:0] operator;
    wire Equation_Ready;
    wire encoder_error;
    wire alu_error;

    // Combine error signals
    assign error = encoder_error | alu_error;

    // Instantiate Input_Reader
    Input_Reader u_Input_Reader (
        .clk(clk),
        .rst(rst),
        .button_value(button_value),
        .button_valid(button_valid),
        .expression_buffer(expression_buffer),
        .expression_ready(expression_ready),
        .count(count)
    );

    // Instantiate Encoder_Block
    Encoder_Block u_Encoder_Block (
        .expression(expression_buffer),
        .expression_ready(expression_ready),
        .expression_len(count),
        .rst(rst),
        .clk(clk),
        .operand(operand),
        .operator(operator),
        .Equation_Ready(Equation_Ready),
        .error(encoder_error)
    );

    // Instantiate ALU_Block
    ALU_Block u_ALU_Block (
        .operand(operand),
        .operator(operator),
        .Equation_Ready(Equation_Ready),
        .clk(clk),
        .rst(rst),
        .answer(answer),
        .error(alu_error)
    );

endmodule
