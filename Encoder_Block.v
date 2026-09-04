/* 
 Description: Converts a 40x4 input array into an equation format.
 Outputs    : 4 numeric tokens (operands) and 3 operator tokens.
 Note       : Missing or invalid operands are padded with '0'. 
              Missing or invalid operators are padded with '+'.
 */

module Encoder_Block (
    input wire [159:0] expression,
    input wire       expression_ready,
    input wire [5:0] expression_len,     // number of digit 
    input wire       rst, clk,
    output reg [95:0] operand,    // max is 167772.16
    output reg [5:0]  operator,    // (+ - * /) <=> 00 01 10 11
    output reg Equation_Ready,
    output reg error
);
`include "calculator_defs.vh"


//==========================================================================================================================
// main FSM
//==========================================================================================================================
reg[3:0]  current_state,
          next_state ;
localparam  [3:0]    IDLE  = 4'b0001,
                     READ  = 4'b0010,
                     ERROR = 4'b0100,
					 DONE  = 4'b1000;
reg finish_flag,
    error_flag;
//==========================================================================================================================
// FSM for read operation
//==========================================================================================================================
reg [2:0] read_state;
localparam [2:0] READ_INT  = 3'b001,  
                 READ_FRAC = 3'b010,  
                 READ_SAVE = 3'b100; 
reg[23:0] current_operand;
wire[3:0]  current_digit;
reg [2:0] op_idx, num_idx, int_count, frac_count;
reg [5:0] array_index;

//==========================================================================================================================
// state transition 	
//==========================================================================================================================	
always @(posedge clk or negedge rst)
 begin
  if(!rst)
   begin
        current_state <= IDLE ;
   end
  else
   begin
     current_state <= next_state ;
   end
 end
//==========================================================================================================================
// next_state logic
//==========================================================================================================================
always @(*)
 begin
  case(current_state)
  IDLE  : begin
            if (expression_ready) next_state = READ;
            else                  next_state = IDLE;
          end
  READ  : begin
            if (finish_flag) next_state = DONE;
            else if (error_flag) next_state = ERROR;
            else next_state = READ;
          end
  ERROR : begin
          next_state = ERROR;
          end
  DONE  : begin
          next_state = DONE;
          end
  default : next_state = IDLE;  	    
  endcase
end	


assign current_digit = expression[array_index*4 +: 4]; 

//==========================================================================================================================
// next_state logic
//==========================================================================================================================
always @(posedge clk )
begin
     case(current_state)
     IDLE  : begin 
        operand[0*24 +: 24]  <= 0; 
        operand[1*24 +: 24]  <= 0;
        operand[2*24 +: 24]  <= 0;
        operand[3*24 +: 24]  <= 0;
        operator[0*2 +: 2] <= 0;
        operator[1*2 +: 2] <= 0;
        operator[2*2 +: 2] <= 0;
        Equation_Ready <= 0;
        error <=0;
        finish_flag <= 0;
        error_flag  <=0;
        current_operand <=0;
        array_index <= 0;
        num_idx <= 0;
        op_idx <= 0;
        read_state <= READ_INT;
        int_count <= 0;
        frac_count <=0;     
     end 
     READ  : begin
          case(read_state)
          READ_INT: 
          begin 
              if ( array_index >= expression_len ) 
                  begin
                      if(int_count==0) error_flag <= 1;
                      // 123 int_count = 3, we need 1230000
                      else 
                      begin
                      current_operand <= current_operand * 100;
                      read_state <= READ_SAVE ; 
                      end 
                  end 
              else if (current_digit == CHAR_DOT) 
                  begin
                      current_operand <= current_operand * 100;
                      read_state <= READ_FRAC;
                      array_index <= array_index + 1;
                  end 
              else if (current_digit <= 4'd9)
                  begin
                      if (int_count < 5) begin 
                          current_operand <= current_operand * 10 + current_digit;
                          int_count   <= int_count   + 1;
                          array_index <= array_index + 1;
                       end 
                      else error_flag <= 1;
                  end 
              else if (!(current_digit <= 4'd9) )        
                  begin
                      if(int_count==0) error_flag <= 1;
                      // 123 int_count = 3, we need 1230000
                      else 
                      begin
                      current_operand <= current_operand * 100;
                      read_state <= READ_SAVE ; 
                      end 
                  end 
          end
          READ_FRAC:
          begin 
              if (array_index >= expression_len)
                 begin 
                      if(frac_count==0) error_flag <= 1;
                      read_state <= READ_SAVE;
                end
              else if  (current_digit == CHAR_DOT) error_flag <= 1;
              else if (current_digit <= 4'd9) 
                  begin
                    if (frac_count <= 0) begin 
                      current_operand <= current_operand + current_digit*10;
                      frac_count <= frac_count + 1;  
                      array_index <= array_index + 1;
                    end
                    else if (frac_count == 1) begin 
                      current_operand <= current_operand + current_digit;
                      frac_count <= frac_count + 1;  
                      array_index <= array_index + 1;
                    end
                    else error_flag <= 1;
                  end 
              else if (!(current_digit <= 4'd9) )
                  begin 
                      if(frac_count==0) error_flag <= 1;
                      read_state <= READ_SAVE;
                  end
          end 
          READ_SAVE:
          begin
              operand[num_idx*24 +: 24] <= current_operand;
              num_idx <= num_idx +1;
              if(!(current_digit <= 4'd9)) 
              begin 
                 case(current_digit)                     
                 CHAR_MUL: operator[op_idx*2 +: 2] <= 2'b10;
                 CHAR_ADD: operator[op_idx*2 +: 2] <= 2'b00;
                 CHAR_SUB: operator[op_idx*2 +: 2] <= 2'b01;
                 CHAR_DIV: operator[op_idx*2 +: 2] <= 2'b11;
                 endcase 
              end 
              op_idx <= op_idx + 1;
              current_operand <= 0;
              read_state <= READ_INT;
              array_index <= array_index + 1;
              int_count <= 0;
              frac_count <=0;
              if(array_index >= expression_len) finish_flag <= 1;
          end 
          endcase 
          end
     ERROR : begin
	        error <= 1;  
          end
     DONE  : begin
            Equation_Ready <= 1;
          end
     default : ;	    
     endcase 
end			  	
endmodule			
