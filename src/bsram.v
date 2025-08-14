`include "bsram.vh"

module bsram_bank #(parameter CELL_ADDR_WIDTH = 32, parameter N_CELLS = 512)
(
	 input  wire clock,
	 input  wire write_enable,
	 input  wire [CELL_ADDR_WIDTH - 1 : 0] addr,
	 input  wire [3  : 0] byte_enables,
	 input  reg  [31 : 0] data_in,
	 output reg  [31 : 0] data_out
);

	reg [31 : 0] cells [N_CELLS - 1 : 0];
	
	always @(posedge clock) begin
		if (write_enable) begin
            if (byte_enables[0]) cells[addr[$clog2(N_CELLS)-1:0]][7  :  0] <= data_in[7  :  0];
            if (byte_enables[1]) cells[addr[$clog2(N_CELLS)-1:0]][15 :  8] <= data_in[15 :  8]; 
            if (byte_enables[2]) cells[addr[$clog2(N_CELLS)-1:0]][23 : 16] <= data_in[23 : 16];
            if (byte_enables[3]) cells[addr[$clog2(N_CELLS)-1:0]][31 : 24] <= data_in[31 : 24];
        end
        
		data_out <= cells[addr];
	end
	
endmodule

module bsram #(parameter ADDR_WIDTH = 32, parameter CELLS_PER_BANK = 512, parameter N_BANKS = 8)
	(
		input  wire	clock,
		input  wire [`BSRAM_COMMAND_BITS - 1 : 0] command,
		input  wire [ADDR_WIDTH - 1 : 0] addr_in,
		input  wire [31 : 0] data_in,
		output wire [31 : 0] data_out,
		
		output reg  [3  : 0] byte_enables,
		
		output reg data_ready		= 0,
		
		output wire busy  			= reading | writing | otherwise_busy,
		output reg valid 			= 1,
		
		output reg alignment_error 	= 0
	);
	
	localparam BANK_ADDR_WIDTH = $clog2(N_BANKS);
	localparam CELL_ADDR_WIDTH = $clog2(CELLS_PER_BANK);
	
	wire [BANK_ADDR_WIDTH - 1 : 0] bank   = addr_in[CELL_ADDR_WIDTH + BANK_ADDR_WIDTH - 1 : CELL_ADDR_WIDTH];
	wire [CELL_ADDR_WIDTH - 1 : 0] offset = addr_in[CELL_ADDR_WIDTH                   - 1 :               0];
	
	wire [31:0] data_out_array [N_BANKS-1:0];
	
	genvar i;
	generate
		for (i = 0; i < N_BANKS; i = i + 1) begin : banks
			bsram_bank #(.CELL_ADDR_WIDTH(CELL_ADDR_WIDTH), .N_CELLS(CELLS_PER_BANK)) bank_inst
			(
				.clock(clock),
				.byte_enables(byte_enables),
				.addr(offset), 
				.data_in(data_to_banks),
				.data_out(data_out_array[i]),
				.write_enable(write_enable && (bank == i))
			);
		end
	endgenerate
	
	assign data_out = data_out_array[bank];
	
	reg [CELL_ADDR_WIDTH - 1 : 0] addr_to_banks;
	reg write_enable;
	reg [31:0] data_to_banks;
	
	localparam BSRAM_STATE_READY 		= 0;
	localparam BSRAM_STATE_READ_FIN 	= 1;
	localparam BSRAM_STATE_ERROR 		= 255;
	localparam BSRAM_STATE_WRITE_FIN 	= 4;
	
	localparam BSRAM_STATE_BITS = $clog2(BSRAM_STATE_ERROR);
	
	reg [31:0] working_addr;
	
	reg [BSRAM_STATE_BITS - 1 : 0] state = BSRAM_STATE_READY;
	reg [BSRAM_STATE_BITS - 1 : 0] return_state;
	
	reg reading = 0;
	reg writing = 0;
	reg otherwise_busy = 0;
	
	wire [1:0] sub_addr = addr_in[1:0];
	
	always @(posedge clock) begin
		case (state)
			BSRAM_STATE_ERROR: begin
				write_enable   <= 0;
				reading 	   <= 0;
				writing 	   <= 0;
				otherwise_busy <= 0;
				
				if (command == `BSRAM_COMMAND_RESTORE) begin
					valid 			<= 1;
					state 			<= BSRAM_STATE_READY;
				end
			end
			
			BSRAM_STATE_READY: begin
				write_enable   <= 0;
				reading 	   <= 0;
				writing 	   <= 0;
				otherwise_busy <= 0;
				
				case (command)
				`BSRAM_COMMAND_READ32: begin
						data_ready <= 0;
						
						if (sub_addr != 2'b00) begin
							alignment_error <= 1;
							valid			<= 0;
							state 			<= BSRAM_STATE_ERROR;
						end
						else begin
							reading <= 1;
							
							addr_to_banks <= addr_in[CELL_ADDR_WIDTH + 1 : 2];
							byte_enables  <= 4'b1111;
							
							state <= BSRAM_STATE_READ_FIN;
						end
					end
				
				`BSRAM_COMMAND_WRITE32: begin
						data_ready <= 0;
						
						if (sub_addr != 2'b00) begin
							alignment_error <= 1;
							
							valid <= 0;
							state <= BSRAM_STATE_ERROR;
						end
						else begin
							writing			<= 1;
							
							addr_to_banks  	<= addr_in[CELL_ADDR_WIDTH + 1 : 2];
							data_to_banks	<= data_in;
							write_enable 	<= 1;
							byte_enables	<= 4'b1111;
							state 			<= BSRAM_STATE_READY;
						end
					end
				endcase
			end
			
			BSRAM_STATE_READ_FIN: begin
				reading 	<= 0;
				data_ready 	<= 1;
				
				state <= BSRAM_STATE_READY;
			end
		endcase
	end
endmodule
