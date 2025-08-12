`define ALU_OPERATION_WIDTH 5

`define ALU_OP_PT1		0
`define ALU_OP_PT2		1
`define ALU_OP_ADD 		2
`define ALU_OP_SUB 		3
`define ALU_OP_AND 		4
`define ALU_OP_OR  		5
`define ALU_OP_XOR 		6
`define ALU_OP_MUL 		7
`define ALU_OP_MULH 	8
`define ALU_OP_MULHU 	9
`define ALU_OP_MULHSU 	10
`define ALU_OP_DIV 		11
`define ALU_OP_DIVU 	12
`define ALU_OP_REM 		13
`define ALU_OP_REMU 	14
`define ALU_OP_LSH		15
`define ALU_OP_RSH		16
`define ALU_OP_ARSH		17

module index_of_first_1
(
    input  wire [31:0] in,
    output reg  [4:0]  out
);
    integer i;
    always @(*) begin
        out = 31;
        for (i = 0; i < 32; i = i + 1) begin
            if (in[i]) begin
                out = i[4:0];
                break;
            end
        end
    end
endmodule

module index_of_last_1
(
    input  wire [31:0] in,
    output reg  [4:0]  out
);
    integer i;
    always @(*) begin
        out = 0;
        for (i = 31; i > 0; i = i - 1) begin
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
	
	output reg result_ready = 0,
	output reg [31:0] out_sync,
	output reg overflow = 0,
	output reg [31:0] out_async,
	output reg async_overflow = 0,
	
	output reg busy = 0
);
	
	wire muliply = (operation == `ALU_OP_MUL || operation == `ALU_OP_MULH || operation == `ALU_OP_MULHU || operation == `ALU_OP_MULHSU);
	wire divide  = (operation == `ALU_OP_DIV || operation == `ALU_OP_DIVU || operation == `ALU_OP_REM   || operation == `ALU_OP_REMU);
	wire rem	 = (operation == `ALU_OP_REM || operation == `ALU_OP_REMU);
	
	wire [1:0] signedness = {
		(operation == `ALU_OP_DIV) || (operation == `ALU_OP_REM) || (operation == `ALU_OP_MUL) || (operation == `ALU_OP_MULH),
		(operation == `ALU_OP_DIV) || (operation == `ALU_OP_REM) || (operation == `ALU_OP_MUL) || (operation == `ALU_OP_MULH) || (operation == `ALU_OP_MULHSU)
	};
	wire mul_return_high = muliply & (operation != `ALU_OP_MUL);
	
	wire [31:0] in1_sabs = (signedness[0] & in1[31]) ? -in1 : in1;
	wire [31:0] in2_sabs = (signedness[1] & in2[31]) ? -in2 : in2;
	
	//asynchronous operations; result is given by continuous assignment
	always @(*) begin
		case (operation)
			`ALU_OP_PT1: out_async = in1;
			`ALU_OP_PT2: out_async = in2;
			
			`ALU_OP_ADD: out_async = in1 + in2;
			`ALU_OP_SUB: out_async = in1 - in2;
			`ALU_OP_AND: out_async = in1 & in2;
			`ALU_OP_OR:  out_async = in1 | in2;
			`ALU_OP_XOR: out_async = in1 ^ in2;
			
			`ALU_OP_LSH:  out_async = in1 << in2;
			`ALU_OP_RSH:  out_async = in1 >> in2;
			`ALU_OP_ARSH: out_async = $signed(in1) >>> in2;
			
			default: out_async = 0;
		endcase
	end
	
	localparam ALU_STATE_READY		 = 0;
	localparam ALU_STATE_MULTIPLYING = 1;
	localparam ALU_STATE_DIVIDING	 = 2;
	localparam ALU_STATE_ERROR		 = 3;
	
	localparam ALU_STATE_BITS = $clog2(ALU_STATE_READY + ALU_STATE_MULTIPLYING + ALU_STATE_DIVIDING + ALU_STATE_ERROR);
	
	reg [ALU_STATE_BITS - 1 : 0] state = ALU_STATE_READY;
	
	wire [4:0] in1_first_1;
	wire [4:0] in2_first_1;
	wire [4:0] in1_last_1;
	wire [4:0] in2_last_1;
	wire [4:0] in2_sabs_last_1;
	
	index_of_first_1 pe1(in1, in1_first_1);
	index_of_first_1 pe2(in2, in2_first_1);
	index_of_last_1  pe3(in1, in1_last_1);
	index_of_last_1  pe4(in2, in2_last_1);
	index_of_last_1  pe5(in2[31] ? -in2 : in2, in2_sabs_last_1);
	
	wire [4:0] div_start_index = in1_last_1 - (signedness[1] ? in2_sabs_last_1 : in2_last_1);
	
	reg negate_latched;
	reg mul_return_high_latched;
	
	reg [63:0] mul_accumulator;
	reg [31:0] div_accumulator;
	
	reg [31:0] dividend;
	reg [31:0] divisor;
	
	wire [31:0] dividend_next 		 = (dividend >= divisor) ? dividend - divisor : dividend;
	wire [31:0] div_accumulator_next = div_accumulator | ((dividend >= divisor) ? (32'd1 << index) : 0);
	wire [31:0] divisor_next  		 = divisor >> 1;
	
	reg [$clog2(32) - 1 : 0] index;
	
	reg [31:0] in1_latched;
	reg [31:0] in2_latched;
	
	reg [63:0] in1_latched_ext;
	
	wire [4:0] in2_first_1_rounded = {in2_first_1[4:2], 2'b00};
	
	wire [63:0] mul_partial_summand1 = in2_latched[index + 0] ? (in1_latched_ext << (index + 0)) : 0;
	wire [63:0] mul_partial_summand2 = in2_latched[index + 1] ? (in1_latched_ext << (index + 1)) : 0;
	wire [63:0] mul_partial_summand3 = in2_latched[index + 2] ? (in1_latched_ext << (index + 2)) : 0;
	wire [63:0] mul_partial_summand4 = in2_latched[index + 3] ? (in1_latched_ext << (index + 3)) : 0;
	
	wire [63:0] mul_next_partial_sum 			=  mul_accumulator + mul_partial_summand1 + mul_partial_summand2 + mul_partial_summand3 + mul_partial_summand4;
	wire [63:0] mul_next_partial_sum_neg 		= -mul_next_partial_sum;
	wire [63:0] mul_next_partial_sum_cneg 		=  negate_latched 			? mul_next_partial_sum_neg 		: mul_next_partial_sum;
	wire [31:0] mul_next_partial_sum_cneg_ch 	=  mul_return_high_latched ? mul_next_partial_sum_cneg[63:32] : mul_next_partial_sum_cneg[31:0];
	
	always @(posedge clock) begin
		case (state)
			ALU_STATE_READY: begin
				if (trigger_sync) begin
					busy 		 <= 1;
					result_ready <= 0;
					
					in1_latched <= in1;
					in2_latched <= in2;
					
					if (muliply) begin
						if (in1 == 0 || in2 == 0) begin
							busy 		 <= 0;
							out_sync 	 <= 0;
							result_ready <= 1;
						end
						else begin
							mul_accumulator <= 0;
							index 		<= in2_first_1_rounded;
							
							if (signedness[0]) in1_latched_ext <= {{32{in1[31]}}, in1};
							else					in1_latched_ext <= { 32'd0,		   in1};
							
							if (signedness[1]) begin
								in2_latched 	<= in2[31] ? -in2 : in2;
								negate_latched 	<= in2[31];
							end
							else begin
								negate_latched 	<= 0;
							end
							
							mul_return_high_latched <= mul_return_high;
							
							state <= ALU_STATE_MULTIPLYING;
						end
					end
					else if (divide) begin
						if (in2 == 32'd0) begin
							busy 		 <= 0;
							out_sync 	 <= rem ? in1 : 32'hffffffff;
							result_ready <= 1;
						end
						else if (in1 == 32'd0) begin
							busy 		 <= 0;
							out_sync 	 <= 0;
							result_ready <= 1;
						end
						else if (in2 == in1) begin
							busy 		 <= 0;
							out_sync 	 <= rem ? 0 : 1;
							result_ready <= 1;
						end
						else if (signedness[0] && in2 == -in1) begin
							busy 		 <= 0;
							out_sync 	 <= rem ? 0 : -1;
							result_ready <= 1;
						end
						else if (!signedness[0] && ($unsigned(in1) < $unsigned(in2))) begin
							busy 		 <= 0;
							out_sync 	 <= rem ? in1 : 0;
							result_ready <= 1;
						end
						else if (signedness[0] && in1_sabs < in2_sabs) begin
							busy 		 <= 0;
							out_sync 	 <= rem ? (in1[31] ? -in1_sabs : in1_sabs) : 0;
							result_ready <= 1;
						end
						else if (in2 == 1) begin
							busy 		 <= 0;
							out_sync 	 <= rem ? 0 : in1;
							result_ready <= 1;
						end
						else if (signedness[1] && in2 == -1) begin
							busy 		 <= 0;
							out_sync 	 <= rem ? 0 : -in1;
							result_ready <= 1;
						end
						else begin
							in2_latched 	<=  (signedness[1] & in2[31]) ? -in2 : in2;
							dividend 		<=  (signedness[1] & in1[31]) ? -in1 : in1;
							divisor  		<= ((signedness[1] & in2[31]) ? -in2 : in2) << div_start_index;
							
							div_accumulator <= 0;
							index 			<= div_start_index;
							
							negate_latched 	<= rem ? signedness[1] & in1[31] : signedness[1] & (in1[31] ^ in2[31]);
							
							state			<= ALU_STATE_DIVIDING;
						end
					end
				end
			end
			
			ALU_STATE_MULTIPLYING: begin
				if (index == 28) begin
					out_sync <= mul_next_partial_sum_cneg_ch;
					
					result_ready <= 1;
					busy 		 <= 0;
					state 		 <= ALU_STATE_READY;
				end
				else begin
					mul_accumulator <= mul_next_partial_sum;
					index			<= index + 4;
				end
			end
			
			ALU_STATE_DIVIDING: begin
				if (index == 0) begin
					out_sync <= negate_latched ? (rem ? -dividend_next : -div_accumulator_next) : (rem ? dividend_next : div_accumulator_next);
					
					result_ready <= 1;
					busy 		 <= 0;
					state 		 <= ALU_STATE_READY;
				end
				else begin
					dividend 		<= dividend_next;
					divisor  		<= divisor_next;
					div_accumulator <= div_accumulator_next;
					index 			<= index - 1;
				end
			end
		endcase
	end
	
endmodule
