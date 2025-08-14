module register_file
(
	input wire clock,
	input wire clock_enable,
	input wire write_enable,
	
	
	input reg  [4:0] 	rd,
	input reg  [4:0] 	rs1,
	input reg  [4:0] 	rs2,
	
	output wire [31:0] 	rs1_out,
	output wire [31:0] 	rs2_out,
	
	output wire [31:0] 	pc_out
);

	reg [31:0] registers [4:0];
	reg [31:0] pc;
	
	assign rs1_out = (rs1 == 0) ? 32'd0 : registers[rs1];
	assign rs2_out = (rs2 == 0) ? 32'd0 : registers[rs2];
	
	assign pc_out = pc;
	
	initial begin
		
	end

	always @(posedge clock) begin
		if (clock_enable) begin
		
		end
	end
endmodule
