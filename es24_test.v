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

module cardreader(reset, clk, brush, pulses, columns);
	input wire reset;
	input wire clk;
	output [15:0] pulses;
	reg [15:0] brushtime;
	output wire [0:79] columns;
	reg [3:0] timer;
	output reg brush;

	reg havecard;
	reg wantcard;
	reg [0:79] card[0:11];

	integer line;
	integer file, c;

	initial begin
		timer = -1;
		brushtime = 1;
		havecard = 0;
		wantcard = 1;
		brush = 0;

		file = $fopenr("card_output.txt");
		if(file == 0)
			$display("FAIL");
	end

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
			card[line][i] = c != " ";
			c = $fgetc(file);
		end
		$display("%b", card[line]);
		if($feof(file)) begin
			$fclose(file);
			file = 0;
		end
	end
end
endtask

	always @(*) if(wantcard) begin
	//	#100;
		for(line = 11; line >= 0; line = line-1)
			readline;
	$display("");
		wantcard <= 0;
		if(file != 0) begin
			brushtime <= 1;
			timer <= -1;
			havecard <= 1;
		end
	end

	always @(posedge clk)
		if(havecard) begin
			brushtime <= { brushtime[14:0], brushtime[15] };
			timer <= timer + 1;
		end

	always @(posedge brushtime[0]) begin
		if(~reset) begin
			brush <= ~brush;
			if(brush) begin
				havecard <= 0;
				wantcard <= file != 0;
			end
		end
	end
//	assign columns = timer <= 11 ? card[timer] : 80'bx;
	assign columns = timer <= 11 ? card[timer] : 80'b0;
	assign pulses[9] = brushtime[1] & clk;
	assign pulses[8] = brushtime[2] & clk;
	assign pulses[7] = brushtime[3] & clk;
	assign pulses[6] = brushtime[4] & clk;
	assign pulses[5] = brushtime[5] & clk;
	assign pulses[4] = brushtime[6] & clk;
	assign pulses[3] = brushtime[7] & clk;
	assign pulses[2] = brushtime[8] & clk;
	assign pulses[1] = brushtime[9] & clk;
	assign pulses[0] = brushtime[10] & clk;
	assign pulses[11] = brushtime[11] & clk;
	assign pulses[12] = brushtime[12] & clk;
	assign pulses[13] = brushtime[13] & clk;
	assign pulses[14] = brushtime[14] & clk;
	assign pulses[15] = brushtime[15] & clk;
	assign pulses[10] = 0;
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
//		default: decimal = 4'bx;
		default: decimal = 4'b0;
		endcase
endmodule

module test;
	initial begin
		$dumpfile("dump.vcd");
		$dumpvars();
		#450000 $finish;
	end

	wire clk, reset;
	wire [31:0] clk_div;
	wire clk_card;

	// clock for ES24 oscillator
	clock clock(clk, reset);
	clockdiv clockdiv(clk, clk_div);
	assign clk_card = clk_div[6];

	wire [15:0] timing;
	wire [0:79] data;
	wire brush;
	cardreader crdrd(reset, clk_card, brush, timing, data);
	wire [15:0] timing_brush1 = brush == 0 ? timing : 0;
	wire [15:0] timing_brush2 = brush == 1 ? timing : 0;
	wire [0:79] data_brush1 = brush == 0 ? data : 0;
	wire [0:79] data_brush2 = brush == 1 ? data : 0;


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

endmodule
