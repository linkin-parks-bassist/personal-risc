`define ALU_OPERATION_WIDTH 4

`define ALU_OP_PT1		0
`define ALU_OP_PT2		1
`define ALU_OP_ADD 		2
`define ALU_OP_SUB 		3
`define ALU_OP_AND 		4
`define ALU_OP_OR  		5
`define ALU_OP_XOR 		6
`define ALU_OP_MUL 		7
`define ALU_OP_MULH 	9
`define ALU_OP_MULHU 	10
`define ALU_OP_MULHSU 	11
`define ALU_OP_DIV 		12
`define ALU_OP_DIVU 	13
`define ALU_OP_REM 		14
`define ALU_OP_REMU 	15

`define ALU_STATE_BITS 8

`define ALU_STATE_READY 0
`define ALU_STATE_MULTIPLYING 1

module index_of_first_1
(
    input  wire [31:0] in,
    output reg  [4:0]  out
);
    integer i;
    always @(*) begin
        out = 0;
        for (i = 0; i < 32; i = i + 1) begin
            if (in[i]) begin
                out = i[4:0];
                break;
            end
        end
    end
endmodule

module alu
(
	input wire clock,
	input wire [`ALU_OPERATION_WIDTH - 1 : 0] operation,
	input wire [31:0] in1, input wire [31:0] in2,
	input wire trigger_sync,
	
	output reg busy = 0,
	output reg result_ready = 0,
	output reg [31:0] out_sync,
	output reg overflow = 0,
	output reg [31:0] out_async,
	output reg async_overflow = 0
);
	
	wire multiply = (operation == `ALU_OP_MUL || operation == `ALU_OP_MULH || operation == `ALU_OP_MULHU || operation == `ALU_OP_MULHSU);
	reg [`ALU_OPERATION_WIDTH - 1 : 0] op_in_progress;
	wire return_high = (op_in_progress == `ALU_OP_MULH || operation == `ALU_OP_MULHU || operation == `ALU_OP_MULHSU);
	
	reg [1:0] signedness;
	
	reg [63:0] accumulator;
	reg [31:0] in1_saved;
	reg [31:0] in2_saved;
	
	wire [4:0] in2_2_exp;
	index_of_first_1 pe(in2, in2_2_exp);
	
	reg [4:0] exp2;
	
	//asynchronous operations; result is given by continuous assignment
	always @(*) begin
		case (operation)
			`ALU_OP_PT1: out_async = in1;
			`ALU_OP_PT2: out_async = in2;
			
			`ALU_OP_ADD: out_async = in1 + in2;
			`ALU_OP_SUB: out_async = in1 - in2;
			`ALU_OP_SUB: out_async = in1 & in2;
			`ALU_OP_SUB: out_async = in1 | in2;
			`ALU_OP_SUB: out_async = in1 ^ in2;
			
			default: out_async = 0;
		endcase
	end
	
	reg [`ALU_STATE_BITS - 1 : 0] state;
	
	wire [63:0] summer1 = in2_saved[exp2 + 0] ? ({{32{signedness[0] ? in1_saved[31] : 1'b0}}, in1_saved} << (exp2 + 0)) : 0;
	wire [63:0] summer2 = in2_saved[exp2 + 1] ? ({{32{signedness[0] ? in1_saved[31] : 1'b0}}, in1_saved} << (exp2 + 1)) : 0;
	wire [63:0] summer3 = in2_saved[exp2 + 2] ? ({{32{signedness[0] ? in1_saved[31] : 1'b0}}, in1_saved} << (exp2 + 2)) : 0;
	wire [63:0] summer4 = in2_saved[exp2 + 3] ? ({{32{signedness[0] ? in1_saved[31] : 1'b0}}, in1_saved} << (exp2 + 3)) : 0;
	
	//synchronous operations; result takes multiple clock cycles
	always @(posedge clock) begin
		case (state)
			`ALU_STATE_READY: begin
				if (trigger_sync) begin
					op_in_progress <= operation;
					result_ready <= 0;
					busy <= 1;
					
					in1_saved <= in1;
					in2_saved <= in2;
					
					if (multiply) begin
						if (in1 == 0 || in2 == 0) begin
							out_sync		<= 0;
							result_ready 	<= 1;
							busy 			<= 0;
						end
						else begin
							case (operation)
								`ALU_OP_MUL:    signedness <= 2'b11;
								`ALU_OP_MULH:   signedness <= 2'b11;
								`ALU_OP_MULHU:  signedness <= 2'b00;
								`ALU_OP_MULHSU: signedness <= 2'b10;
							endcase
							
							accumulator <= {{32{signedness[0] ? in1_saved[31] : 1'b0}}, in1} << in2_2_exp;
							exp2 <= in2_2_exp + 1;
							
							state <= `ALU_STATE_MULTIPLYING;
						end
					end
				end
			end
			
			`ALU_STATE_MULTIPLYING: begin
				accumulator <= accumulator + summer1 + summer2 + summer3 + summer4;
				
				if (exp2 >= 28) begin
					out_sync		<= return_high ? accumulator[63:32] : accumulator[31:0];
					result_ready 	<= 1;
					busy 			<= 0;
					state 			<= `ALU_STATE_READY;
				end
				else begin
					exp2 <= exp2 + 4;
				end
			end
		endcase
	end
	
endmodule
