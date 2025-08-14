`include "instruction_type.vh"
`include "alu.vh"

module instr_decoder
(
	input  wire [31:0] 	instr,
	output reg  [4:0] 	rd,
	output reg  [4:0] 	rs1,
	output reg  [4:0] 	rs2,
	output reg  [31:0] 	imm,
	
	output reg rd_enable,
	output reg rs1_enable,
	output reg rs2_enable,
	output reg imm_enable,
	
	output reg [`INSTR_TYPE_WIDTH - 1: 0] instr_type,
	
	output reg [`ALU_OPERATION_WIDTH - 1: 0] alu_op,
	
	output reg valid = 1
);

	localparam INSTR_FORMAT_R = 1;
	localparam INSTR_FORMAT_I = 2;
	localparam INSTR_FORMAT_S = 3;
	localparam INSTR_FORMAT_U = 4;

	localparam INSTR_FORMAT_B = 5;
	localparam INSTR_FORMAT_J = 6;

	reg [6:0] opcode = instr[6:0];
	
	reg [2:0] format;
	reg [2:0] funct3;
	reg [6:0] funct7;
	
	reg funct3_enable;
	reg funct7_enable;
	
	always @(*) begin
		case (opcode)
			7'b0110011: begin
				format		=  INSTR_FORMAT_R;
				instr_type 	= `INSTR_TYPE_ALU_R;
			end
			7'b0010011: begin
				format		=  INSTR_FORMAT_I;
				instr_type 	= `INSTR_TYPE_ALU_I;
			end

			7'b0000011: begin
				format		=  INSTR_FORMAT_I;
				instr_type 	= `INSTR_TYPE_LOAD;
			end

			7'b1100111: begin
				format		=  INSTR_FORMAT_I;
				instr_type 	= `INSTR_TYPE_JUMP;
			end

			7'b1110011: begin
				format		=  INSTR_FORMAT_I;
				instr_type 	= `INSTR_TYPE_ENV;
			end

			7'b0100011: begin
				format     =  INSTR_FORMAT_S;
				instr_type = `INSTR_TYPE_STORE;
			end

			7'b0110111: begin
				format		=  INSTR_FORMAT_U;
				instr_type 	= `INSTR_TYPE_LUI;
			end

			7'b0010111: begin
				format		=  INSTR_FORMAT_U;
				instr_type 	= `INSTR_TYPE_AUIPC;
			end

			7'b1100011: begin
				format		=  INSTR_FORMAT_B;
				instr_type 	= `INSTR_TYPE_BRANCH;
			end

			7'b1101111: begin
				format		=  INSTR_FORMAT_J;
				instr_type 	= `INSTR_TYPE_JUMP;
			end

			
			default: begin
				format		= `INSTR_INVALID;
				instr_type 	= `INSTR_INVALID;
			end
		endcase
	end
	
	always @(*) begin
		/* Default to assuming R format, so that the cases below
		 * don't have to assign everything to avoid latching */
		rd  	= instr[11: 7];
		rs1 	= instr[19:15];
		rs2 	= instr[24:20];
		
		funct3	= instr[14:12];
		funct7 	= instr[31:25];
		
		funct3_enable = 1;
		funct7_enable = 1;
		
		rd_enable  = 1;
		rs1_enable = 1;
		rs2_enable = 1;
		imm_enable = 1;
		
		case (format)
			INSTR_FORMAT_R: begin
				imm_enable = 0;
			end
			
			INSTR_FORMAT_I: begin
				imm 		= {{20{instr[31]}}, instr[31:20]};
				rs2_enable	= 0;
			end
			
			INSTR_FORMAT_S: begin
				imm 			= {{20{instr[31]}}, instr[31:25], instr[11:7]};
				rd_enable		= 0;
				funct7_enable	= 0;
			end
			
			INSTR_FORMAT_U: begin
				imm 			= {instr[31:12], {12{1'b0}}};
				funct3_enable	= 0;
				funct7_enable	= 0;
				rs1_enable 		= 0;
				rs2_enable 		= 0;
			end
			
			INSTR_FORMAT_B: begin
				imm 			= {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};
				funct7_enable	= 0;
				rd_enable		= 0;
			end
			
			INSTR_FORMAT_J: begin
				imm 			= {{12{instr[31]}}, instr[19:12], instr[20], instr[30:25], instr[24:21], 1'b0};
				funct3_enable	= 0;
				funct7_enable	= 0;
				rs1_enable 		= 0;
				rs2_enable 		= 0;
			end
			
			default: begin
				valid = 0;
			end
		endcase
	end
	
	always @(*) begin
		if ((instr_type == `INSTR_TYPE_ALU_R) || (instr_type == `INSTR_TYPE_ALU_I))
			alu_op = {funct7[1:0], funct3};
		else
			alu_op = `ALU_OP_PT1;
	end
endmodule
