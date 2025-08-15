`include "sram.vh"

module sram_bank #(parameter N_WORDS = 512)
(
	 input  wire clock,
	 input  wire write_enable,
	 input  wire [$clog2(N_WORDS) - 1 : 0] addr,
	 input  wire [31 : 0] bit_mask,
	 input  wire [31 : 0] data_in,
	 output reg  [31 : 0] data_out
);
	
	reg  [31:0] words [N_WORDS - 1 : 0];
	
	always @(posedge clock) begin
		if (write_enable) begin
			words[addr] <= (words[addr] & ~bit_mask) | (data_in & bit_mask);
        end
        
		data_out <= words[addr];
	end
endmodule

module sram #(parameter ADDR_WIDTH = 32, parameter WORDS_PER_BANK = 512, parameter N_BANKS = 8, parameter big_endian = 0)
	(
		input  wire	clock,
		input  wire [`SRAM_COMMAND_BITS - 1 : 0] command,
		input  wire [ADDR_WIDTH - 1 : 0] addr_in,
		input  wire [31 : 0] data_in,
		output reg  [31 : 0] data_out,
		
		output wire valid 			= ~address_error & ~alignment_error,
		output reg address_error 	= 0,
		output reg alignment_error 	= 0
	);
	
	localparam BANK_ADDR_WIDTH = $clog2(N_BANKS);
	localparam WORD_ADDR_WIDTH = $clog2(WORDS_PER_BANK);
	
	wire [BANK_ADDR_WIDTH - 1 : 0] bank   = addr_in[WORD_ADDR_WIDTH + BANK_ADDR_WIDTH + 1 : WORD_ADDR_WIDTH + 2];
	wire [WORD_ADDR_WIDTH - 1 : 0] offset = addr_in[WORD_ADDR_WIDTH                   + 1 :              	  2];
	wire [1:0] sub_word_addr = big_endian ? 3 - addr_in[1:0] : addr_in[1:0];
	
	wire write_enable = valid & ((command == `SRAM_COMMAND_WRITE8) || (command == `SRAM_COMMAND_WRITE16) || (command == `SRAM_COMMAND_WRITE32));
	
	reg [3:0] byte_enables;
	
	always @(*) begin
		if 		((command == `SRAM_COMMAND_READ8)  || (command == `SRAM_COMMAND_WRITE8))  begin
			alignment_error = 0;
			byte_enables = 4'b0001 << sub_word_addr;
		end
		else if ((command == `SRAM_COMMAND_READ16) || (command == `SRAM_COMMAND_WRITE16)) begin
			alignment_error = (sub_word_addr[0] != 0);
			byte_enables 	= 4'b0011 << sub_word_addr;
		end
		else if ((command == `SRAM_COMMAND_READ32) || (command == `SRAM_COMMAND_WRITE32)) begin
			alignment_error = (sub_word_addr[1:0] != 0);
			byte_enables = 4'b1111;
		end
		else begin
			alignment_error = 0;
			byte_enables 	= 4'b0000;
		end
		
		address_error = (addr_in[31: WORD_ADDR_WIDTH + 2] > N_BANKS);
	end
	
	wire [31:0] bit_mask = {{8{byte_enables[3]}}, {8{byte_enables[2]}}, {8{byte_enables[1]}}, {8{byte_enables[0]}}};
	
	wire [31:0] data_to_banks = data_in << ({sub_word_addr, 3'b000});
	
	wire [31:0] data_out_array [N_BANKS-1:0];
	
	genvar i;
	generate
		for (i = 0; i < N_BANKS; i = i + 1) begin : banks
			sram_bank #(.N_WORDS(WORDS_PER_BANK)) bank_inst
			(
				.clock(clock),
				.bit_mask(bit_mask),
				.addr(offset), 
				.data_in(data_to_banks),
				.data_out(data_out_array[i]),
				.write_enable(write_enable && (bank == i))
			);
		end
	endgenerate
	
	reg [1:0] read_offset;
	
	always @(posedge clock) begin
		if ((command == `SRAM_COMMAND_READ8) || (command == `SRAM_COMMAND_READ16) || (command == `SRAM_COMMAND_READ32))
			read_offset <= sub_word_addr;
	end
	
	assign data_out = data_out_array[bank] >> {read_offset, 3'b000};
endmodule
