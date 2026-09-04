/* 
  This module receives user input, including digits 0-9, a decimal point, operators (+, -, *, /), backspace, and reset. 
  When the user enters the '=' character, the output of this module is a 2D array (4x40) of register type.
*/
//THinh

module Input_Reader (
    input wire clk,
    input wire rst,
    input wire [4:0] button_value,   // 5 bits input
    input wire button_valid,
    output reg [159:0] expression_buffer,  // A 40x4 2D register array to store entire operation because we dont need to save equal sign (5 bits)
    output reg expression_ready,
    output reg [5:0] count 
);
`include "calculator_defs.vh"


integer i;

// Sequential logic with asynchronous active-low reset 
always@(posedge clk or negedge rst)
begin
	if (!rst) 
		begin
            for (i = 0; i < 40; i = i + 1) 
                begin
                    expression_buffer[i*4 +: 4] <= 4'd0;
                end
            expression_ready <= 1'b0;
            count <=0;
		end
	else if (button_valid && !expression_ready)
		begin
            if (button_value == CHAR_EQUAL) 
                expression_ready <= 1;
            else if (button_value != CHAR_BACKSPACE && count!=40)
                begin   
                    expression_buffer[count*4 +: 4] <= button_value[3:0];
                    count <= count + 1;
                end 
            else if (button_value == CHAR_BACKSPACE && count != 0)
	            begin
			        expression_buffer[(count-1)*4 +: 4] <= 4'd0;
                    count <= count - 1;
		        end
		end
end
endmodule


