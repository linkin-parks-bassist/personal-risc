`define INSTR_FORMAT_R 5
`define INSTR_FORMAT_I 3
`define INSTR_FORMAT_S 4
`define INSTR_FORMAT_U 0

`define INSTR_FORMAT_B 2
`define INSTR_FORMAT_J 1

`define INSTR_FORMAT_INVALID 6

module instr_decoder
(
	input  wire [31:0] instr,
	output reg  [4:0] rd,
	output reg  [4:0] rs1,
	output reg  [4:0] rs2,
	output reg  [31:0] imm,
	
	output reg invalid_opcode
);

	wire [6:0] opcode = instr[6:0];
	
	reg  [2:0] format;
	reg  [2:0] funct3;
	reg  [6:0] funct7;
	
	always @(*) begin
		invalid_opcode = 0;
		case (opcode)
			7'b0110011: format = `INSTR_FORMAT_R;
			7'b0010011: format = `INSTR_FORMAT_I;
			7'b0000011: format = `INSTR_FORMAT_I;
			7'b1100111: format = `INSTR_FORMAT_I;
			7'b1110011: format = `INSTR_FORMAT_I;
			7'b0100011: format = `INSTR_FORMAT_S;
			7'b0110111: format = `INSTR_FORMAT_U;
			7'b0010111: format = `INSTR_FORMAT_U;
			7'b1100011: format = `INSTR_FORMAT_B;
			7'b1101111: format = `INSTR_FORMAT_J;
			
			default: format = `INSTR_FORMAT_INVALID;
		endcase
	end
	
	always @(*) begin
		rd  = instr[11: 7];
		rs1 = instr[19:15];
		rs1 = instr[24:20];
		
		funct3 = instr[14:12];
		funct7 = instr[31:25];
		
		case (format)
			`INSTR_FORMAT_I: begin
				imm 	= {{20{instr[31]}}, instr[31:20]};
				rs2 	= 0;
				funct7  = 0;
			end
			
			
			`INSTR_FORMAT_S: begin
				imm 	= {{20{instr[31]}}, instr[31:25], instr[11:7]};
				rd		= 0;
				funct7  = 0;
			end
			
			`INSTR_FORMAT_U: begin
				imm 	= {instr[31:12], {12{1'b0}}};
				funct3  = 0;
				funct7  = 0;
				rs1 	= 0;
				rs2 	= 0;
			end
			
			`INSTR_FORMAT_B: begin
				imm 	= {{21{instr[31]}}, instr[7], instr[30:25], instr[11:8]};
				funct7  = 0;
				rd	 	= 0;
			end
			
			`INSTR_FORMAT_J: begin
				imm 	= {{13{instr[31]}}, instr[19:12], instr[20], instr[30:21]};
				funct3  = 0;
				funct7  = 0;
				rs1 	= 0;
				rs2 	= 0;
				rd		= 0;
			end
			
			default: begin end
		endcase
	end

endmodule
