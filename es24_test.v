`default_nettype none
`timescale 1us/1us

module clock(clk, reset);
	output reg clk;
	output reg reset;

	initial begin
		clk = 0;
		reset = 1;
		#500 reset = 0;
	end

	always
		#10 clk = ~clk;
endmodule

module clockdiv(inclk, outclk);
	input wire inclk;
	output reg [31:0] outclk;

	initial outclk = 0;

	always @(posedge inclk)
		outclk <= outclk + 1;
endmodule

module cardreader(reset, clk, pulses, columns1, columns2);
	input wire reset;
	input wire clk;
	output [12:0] pulses;
	output wire [0:79] columns1;
	output wire [0:79] columns2;
	reg [3:0] timer;

	reg wantcard;
	reg [2:1] havecard;
	reg [0:79] card1[0:11];
	reg [0:79] card2[0:11];
	wire endcard = timer == 13;	// card is 0-11, so this is beyond its end


	integer line;
	integer file, c;

	initial begin
		timer = -1;	// so we'll read the first row (0) next tick
		havecard = 0;
		wantcard = 0;

		for(line = 11; line >= 0; line = line-1) begin
			card1[line] = 0;
			card2[line] = 0;
		end

		file = $fopenr("card_output.txt");
		if(file == 0)
			$display("FAIL");
		
		#300;
		wantcard = 1;	// need a card at the beginning
	end

	// read one line of the input file into card[line]
	task readline;
		integer c;
		integer i;
	begin
		if(file != 0)
		if(!$feof(file)) begin
			c = $fgetc(file);
			while(c == ";") begin
				while(c != "\n")
					c = $fgetc(file);
				c = $fgetc(file);
			end
			for(i = 0; i < 80; i = i+1) begin
				card1[line][i] = c != " ";
				c = $fgetc(file);
			end
			$display("%b", card1[line]);
			if($feof(file)) begin
				$fclose(file);
				file = 0;
			end
		end
	end
	endtask

	// Read a new card from file
	always @(*) if(wantcard) begin
		#100;
		for(line = 11; line >= 0; line = line-1)
			readline;
		$display("");
		wantcard <= 0;
		if(file != 0)
			havecard[1] <= 1;
	end

	// Generate timing pulses if there's a card in the reader
	always @(posedge clk)
		if(havecard)
			timer <= timer + 1;

	// Move cards
	always @(posedge endcard) begin
		if(~reset) begin
			// shift card from brush 1 to brush 2
			havecard <= { havecard[1], 1'b0 };
			for(line = 11; line >= 0; line = line-1) begin
				card2[line] <= card1[line];
				card1[line] <= 0;
			end
			// and request new card for brush 1 if there is one
			wantcard <= file != 0;
		end
	end
	assign columns1 = timer <= 11 ? card1[timer] : 80'b0;
	assign columns2 = timer <= 11 ? card2[timer] : 80'b0;
	assign pulses[9] = timer == 0 & clk;
	assign pulses[8] = timer == 1 & clk;
	assign pulses[7] = timer == 2 & clk;
	assign pulses[6] = timer == 3 & clk;
	assign pulses[5] = timer == 4 & clk;
	assign pulses[4] = timer == 5 & clk;
	assign pulses[3] = timer == 6 & clk;
	assign pulses[2] = timer == 7 & clk;
	assign pulses[1] = timer == 8 & clk;
	assign pulses[0] = timer == 9 & clk;
	assign pulses[10] = 0;	// no such thing but we like nice indices
	assign pulses[11] = timer == 10 & clk;
	assign pulses[12] = timer == 11 & clk;
endmodule

module biquinary_decode(biquinary, decimal);
	input wire [0:5] biquinary;
	output reg [3:0] decimal;
	always @(*)
		case(biquinary)
		6'b100000: decimal <= 0;
		6'b010000: decimal <= 1;
		6'b001000: decimal <= 2;
		6'b000100: decimal <= 3;
		6'b000010: decimal <= 4;
		6'b100001: decimal <= 5;
		6'b010001: decimal <= 6;
		6'b001001: decimal <= 7;
		6'b000101: decimal <= 8;
		6'b000011: decimal <= 9;
		default: decimal = 4'b0;
		endcase
endmodule

module test;
	initial begin
		$dumpfile("run/dump.vcd");
		$dumpvars();
		#450000 $finish;
	end

	wire clk, reset;
	wire [31:0] clk_div;
	wire clk_card;

	clock clock(clk, reset);
	clockdiv clockdiv(clk, clk_div);
	assign clk_card = clk_div[6];

	wire [12:0] timing;
	wire [0:79] data_brush1;
	wire [0:79] data_brush2;
	cardreader crdrd(reset, clk_card, timing, data_brush1, data_brush2);

	// Wiring on the plugboard
	// possibly not quite right, especially umkehr and aufnahme
	wire aufnahme1 = timing[12];
	wire aufnahme2 = data_brush1[20];
	wire umkehr1 = timing[12];
	wire umkehr2 = data_brush1[21];
	wire minus1 = timing[11];
	wire minus2 = data_brush1[11];
	wire loeschen = timing[12] & data_brush1[23];
	wire zaehleranalyse = timing[12] & data_brush2[22];
	wire [0:5] ziffer_biqui[1:12];
	wire [12:1] digit_input = data_brush2[0:11];
	wire zaehleranalyse_out;
	es24 es24(reset, clk,
		aufnahme1, aufnahme2,
		umkehr1, umkehr2,
		minus1, minus2,
		loeschen,
		zaehleranalyse,
		timing, digit_input,
		ziffer_biqui[1],
		ziffer_biqui[2],
		ziffer_biqui[3],
		ziffer_biqui[4],
		ziffer_biqui[5],
		ziffer_biqui[6],
		ziffer_biqui[7],
		ziffer_biqui[8],
		ziffer_biqui[9],
		ziffer_biqui[10],
		ziffer_biqui[11],
		ziffer_biqui[12],
		zaehleranalyse_out);

	wire [3:0] ziffer_dez1;
	wire [3:0] ziffer_dez2;
	wire [3:0] ziffer_dez3;
	wire [3:0] ziffer_dez4;
	wire [3:0] ziffer_dez5;
	wire [3:0] ziffer_dez6;
	wire [3:0] ziffer_dez7;
	wire [3:0] ziffer_dez8;
	wire [3:0] ziffer_dez9;
	wire [3:0] ziffer_dez10;
	wire [3:0] ziffer_dez11;
	wire [3:0] ziffer_dez12;
	biquinary_decode bq1(ziffer_biqui[1], ziffer_dez1);
	biquinary_decode bq2(ziffer_biqui[2], ziffer_dez2);
	biquinary_decode bq3(ziffer_biqui[3], ziffer_dez3);
	biquinary_decode bq4(ziffer_biqui[4], ziffer_dez4);
	biquinary_decode bq5(ziffer_biqui[5], ziffer_dez5);
	biquinary_decode bq6(ziffer_biqui[6], ziffer_dez6);
	biquinary_decode bq7(ziffer_biqui[7], ziffer_dez7);
	biquinary_decode bq8(ziffer_biqui[8], ziffer_dez8);
	biquinary_decode bq9(ziffer_biqui[9], ziffer_dez9);
	biquinary_decode bq10(ziffer_biqui[10], ziffer_dez10);
	biquinary_decode bq11(ziffer_biqui[11], ziffer_dez11);
	biquinary_decode bq12(ziffer_biqui[12], ziffer_dez12);

	wire [0:39] zahl_dez =
		ziffer_dez1 +
		ziffer_dez2 * 10 +
		ziffer_dez3 * 100 +
		ziffer_dez4 * 1000 +
		ziffer_dez5 * 10000 +
		ziffer_dez6 * 100000 +
		ziffer_dez7 * 1000000 +
		ziffer_dez8 * 10000000 +
		ziffer_dez9 * 100000000 +
		ziffer_dez10 * 1000000000 +
		ziffer_dez11 * 10000000000 +
		ziffer_dez12 * 100000000000;

endmodule
