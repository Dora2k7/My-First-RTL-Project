module ALU_Block (
    input  [95:0] operand,    
    input  [5:0]  operator,    // (+ - * /) <=> 00 01 10 11
    input  Equation_Ready,
    input  clk, rst,
    output reg [31:0] answer,
    output reg error
);
`include "calculator_defs.vh"


    reg signed [99:0] int_operand;
    reg [5:0]  int_operator;
    reg state;
    reg equation_ready_d;

    localparam IDLE = 1'b0;
    localparam CALC = 1'b1;

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            answer <= 0;
            error <= 0;
            state <= IDLE;
            equation_ready_d <= 0;
            int_operand <= 0;
            int_operator <= 0;
        end else begin
            equation_ready_d <= Equation_Ready;

            case (state)
                IDLE: begin
                    // Detect rising edge of Equation_Ready
                    if (Equation_Ready && !equation_ready_d) begin
                        int_operand <= {1'b0, operand[95:72], 1'b0, operand[71:48], 1'b0, operand[47:24], 1'b0, operand[23:0]};
                        int_operator <= operator;
                        error <= 0;
                        state <= CALC;
                    end
                end

                CALC: begin
                    if (!error) 
                    begin
                        // Pre-pass: Convert SUB to ADD by negating the right operand
                        if (int_operator[0*2 +: 2] == 2'b01) begin
                            int_operand[1*25 +: 25] <= -$signed(int_operand[1*25 +: 25]);
                            int_operator[0*2 +: 2]  <= 2'b00;
                        end
                        else if (int_operator[1*2 +: 2] == 2'b01) begin
                            int_operand[2*25 +: 25] <= -$signed(int_operand[2*25 +: 25]);
                            int_operator[1*2 +: 2]  <= 2'b00;
                        end
                        else if (int_operator[2*2 +: 2] == 2'b01) begin
                            int_operand[3*25 +: 25] <= -$signed(int_operand[3*25 +: 25]);
                            int_operator[2*2 +: 2]  <= 2'b00;
                        end
                        // Check for Divide by zero
                        else if ( ( int_operator[2*2 +: 2] == 2'b11 && int_operand[3*25 +: 25] == 0) ||
                             ( int_operator[1*2 +: 2] == 2'b11 && int_operand[2*25 +: 25] == 0) ||
                             ( int_operator[0*2 +: 2] == 2'b11 && int_operand[1*25 +: 25] == 0) )
                            begin
                                error <= 1; 
                                state <= IDLE; // Abort on divide by zero
                            end  
                        //------------------------------------------------------------------------------------------------------------------ 
                        else if (int_operator[0*2 +: 2] == 2'b10 || int_operator[0*2 +: 2] == 2'b11 )   
                            begin 
                                if(int_operator[0*2 +: 2] == 2'b10)
                                    begin
                                        int_operand[0*25 +: 25] <=  0;
                                        int_operand[1*25 +: 25] <=  ($signed(int_operand[0*25 +: 25])*$signed(int_operand[1*25 +: 25]))/100;
                                        int_operator[0*2 +: 2]   <=  0;
                                    end
                                else begin
                                        int_operand[0*25 +: 25] <=  0;
                                        int_operand[1*25 +: 25] <=  ($signed(int_operand[0*25 +: 25])*100)/$signed(int_operand[1*25 +: 25]);
                                        int_operator[0*2 +: 2]   <=  0;
                                     end 
                            end
                        //------------------------------------------------------------------------------------------------------------------
                        else if (int_operator[1*2 +: 2] == 2'b10 || int_operator[1*2 +: 2] == 2'b11 )
                            begin 
                                if(int_operator[1*2 +: 2] == 2'b10)
                                    begin
                                        int_operand[1*25 +: 25] <=  0;
                                        int_operand[2*25 +: 25] <=  ($signed(int_operand[1*25 +: 25])*$signed(int_operand[2*25 +: 25]))/100;
                                        int_operator[1*2 +: 2]   <=  0;
                                    end
                                else begin
                                        int_operand[1*25 +: 25] <=  0;
                                        int_operand[2*25 +: 25] <=  ($signed(int_operand[1*25 +: 25])*100)/$signed(int_operand[2*25 +: 25]);
                                        int_operator[1*2 +: 2]   <=  0;
                                     end 
                            end
                        //------------------------------------------------------------------------------------------------------------------
                        else if(int_operator[2*2 +: 2] == 2'b10 || int_operator[2*2 +: 2] == 2'b11 ) 
                            begin 
                                if(int_operator[2*2 +: 2] == 2'b10)
                                    begin
                                        int_operand[2*25 +: 25] <=  0;
                                        int_operand[3*25 +: 25] <=  ($signed(int_operand[2*25 +: 25])*$signed(int_operand[3*25 +: 25]))/100;
                                        int_operator[2*2 +: 2]   <=  0;
                                    end
                                else begin
                                        int_operand[2*25 +: 25] <=  0;
                                        int_operand[3*25 +: 25] <=  ($signed(int_operand[2*25 +: 25])*100)/$signed(int_operand[3*25 +: 25]);
                                        int_operator[2*2 +: 2]   <=  0;
                                     end 
                            end 
                        else 
                            begin
                            answer <= $signed(int_operand[0*25 +: 25]) + $signed(int_operand[1*25 +: 25]) + $signed(int_operand[2*25 +: 25]) + $signed(int_operand[3*25 +: 25]);
                            state <= IDLE;
                            end
                    end 
                    else  begin
                        state <= IDLE;
                    end
                end
            endcase
        end
    end


endmodule
