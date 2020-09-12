module edgedet(clk, reset, in, p);
	input wire clk;
	input wire reset;
	input wire in;
	output wire p;

	reg [1:0] x;
	reg [1:0] init = 0;
	always @(posedge clk or negedge reset) begin
		if(reset)
			init <= 0;
		else begin
			x <= { x[0], in };
			init <= { init[0], 1'b1 };
		end
	end

	assign p = (&init) & x[0] & !x[1];
endmodule

module es24(reset, clk,
	aufnahme_in1, aufnahme_in2,
	umkehr_in1, umkehr_in2,
	minus_in1, minus_in2,
	loeschen_in,
	zaehleranalyse_in,
	timing, data,

	ziffer_out1,	// least significant
	ziffer_out2,
	ziffer_out3,
	ziffer_out4,
	ziffer_out5,
	ziffer_out6,
	ziffer_out7,
	ziffer_out8,
	ziffer_out9,
	ziffer_out10,
	ziffer_out11,
	ziffer_out12,

	zaehleranalyse
);

	input wire reset;
	input wire clk;

	input wire aufnahme_in1, aufnahme_in2;
	input wire umkehr_in1, umkehr_in2;
	input wire minus_in1, minus_in2;
	input wire loeschen_in;
	input wire zaehleranalyse_in;

	// from second brush
	input wire [15:0] timing;
	input wire [12:1] data;

	output wire [0:5] ziffer_out1;
	output wire [0:5] ziffer_out2;
	output wire [0:5] ziffer_out3;
	output wire [0:5] ziffer_out4;
	output wire [0:5] ziffer_out5;
	output wire [0:5] ziffer_out6;
	output wire [0:5] ziffer_out7;
	output wire [0:5] ziffer_out8;
	output wire [0:5] ziffer_out9;
	output wire [0:5] ziffer_out10;
	output wire [0:5] ziffer_out11;
	output wire [0:5] ziffer_out12;
	output wire zaehleranalyse;

	/*
	 **************
	 * Streifen 1 *
	 **************
	 */

	// Aufname
	wire aufnahme_and = aufnahme_in1 & aufnahme_in2;	// R12,11
	reg aufnahme_ff;	// R10
	always @(posedge clk) begin
		if(aufnahme_and)
			aufnahme_ff <= 1;
		if(time0)
			aufnahme_ff <= 0;
	end

	// Umkehr
	wire umkehr_and = umkehr_in1 & umkehr_in2;	// R1,2
	reg umkehr_ff;	// R3
	always @(posedge clk) begin
		if(umkehr_and)
			umkehr_ff <= 1;
		if(time0)
			umkehr_ff <= 0;
	end

	// Minus
	wire minus_and = minus_in1 & minus_in2;	// R7,6
	reg minus_ff;	// R5
	always @(posedge clk) begin
		if(minus_and)
			minus_ff <= 1;
		if(time0)
			minus_ff <= 0;
	end

	// Add/Sub
	// R4 - possibly and
	wire op_or1 = umkehr_ff | ~minus_ff;
	wire op_or2 = ~umkehr_ff | minus_ff;
	// R8 - possibly or
	wire op_add = op_or1 & op_or2;
	wire op_sub = ~op_add;
	// R9
	wire add_enb = op_add & aufnahme_ff;
	wire sub_enb = op_sub & aufnahme_ff;

	/*
	 **************
	 * Streifen 2 *
	 **************
	 */

	wire time12 = timing[12];	// R13
	wire time0 = timing[0];	// R14
	wire time9 = timing[9];	// R15
	wire za_set = zaehleranalyse_in & (&analyse);	// R16,R17
	reg zaehleranalyse_ff;	// R18
	always @(posedge clk) begin
		if(za_set)
			zaehleranalyse_ff <= 1;
		if(time9)
			zaehleranalyse_ff <= 0;
	end
	assign zaehleranalyse = zaehleranalyse_ff;	// R19
	wire pot90_amp = ~pot09;	// R24
	wire add = add_enb & pot90_amp;	// R22
	wire sub = sub_enb & pot90_amp;	// R23
	// skipped R20 R21 - identical, used with Streifen 3

	/*
	 **************
	 * Streifen 3 *
	 **************
	 */
	// skipped - identical to Streifen 1

	/*
	 **************
	 * Streifen 4 *
	 **************
	 */

	// R37-R41
	wire pulse_97531 = timing[9] | timing[7] | timing[5] |
		timing[3] | timing[1];
	wire pulse_864212 = timing[8] | timing[6] | timing[4] |
		timing[2] | timing[12];
	// R42-45
// TODO: there's probably more to this
	wire loeschen = loeschen_in;
	reg pot09_ff;	// R46
	always @(posedge clk) begin
		if(time9)
			pot09_ff <= 0;
		if(time0)
			pot09_ff <= 1;
	end
	// R47, R48
// TODO: check timing
	wire pot09 = pot09_ff;
	wire pot90 = ~pot09_ff;

	/*
	 **************
	 * Streifen 5 *
	 **************
	 */

	wire schmitt_odd = pulse_97531;	// R49
	wire schmitt_even = pulse_864212;	// R50
	// R51 - very unsure about this
	wire pulse_odd, pulse_even;
	edgedet e1(clk, reset, !schmitt_odd, pulse_odd);
	edgedet e2(clk, reset, !schmitt_even, pulse_even);
	// R52 - also very unsure about this
	reg pulse_toggle;
	always @(posedge clk) begin
		if(pulse_odd)
			pulse_toggle <= 0;
		if(pulse_even)
			pulse_toggle <= 1;
	end

	// R53 - digit pulses
	wire tmp_pulse1, tmp_pulse2;
	edgedet e3(clk, reset, pulse_toggle, tmp_pulse1);
	edgedet e4(clk, reset, ~pulse_toggle, tmp_pulse2);
	wire count_pulse1 = tmp_pulse1 & digit_enable;
	wire count_pulse2 = tmp_pulse2 & digit_enable;
	// R54 - carry pulses - digit disable
	wire count_pulse3;
	edgedet e5(clk, reset, ~carry_imp, count_pulse3);
	wire digit_enable = ~pot09;
	// R55, R56
	wire count_pulse;
	edgedet e6(clk, reset,
		count_pulse1 | count_pulse2 | count_pulse3,
		count_pulse);
	// R58
	reg [3:0] freischwinger_cnt = 0;
	always @(posedge clk)
		if(pot09)	// R59
			freischwinger_cnt <= freischwinger_cnt + 1;
	wire freischwinger = freischwinger_cnt[3];
	// R57 (?)
	wire carry_imp;
	edgedet e7(clk, reset, freischwinger, carry_imp);
	// R60 - not quite sure
	wire carry_clr;
	edgedet e8(clk, reset, ~freischwinger, carry_clr);


	wire [12:1] carry;
	wire [12:1] analyse;
	es24_zaehler z1(.reset(reset), .clk(clk),
		.init(time12), .digit_time(data[1]),
		.add_enb(add), .sub_enb(sub), .carry_enb(pot09),
		.carry_in(carry[12]), .carry_out(carry[1]),
		.count_pulse(count_pulse), .clr(loeschen),
		.carry_clr(carry_clr),
		.digit(ziffer_out1), .za(analyse[1]));
	es24_zaehler z2(.reset(reset), .clk(clk),
		.init(time12), .digit_time(data[2]),
		.add_enb(add), .sub_enb(sub), .carry_enb(pot09),
		.carry_in(carry[1]), .carry_out(carry[2]),
		.count_pulse(count_pulse), .clr(loeschen),
		.carry_clr(carry_clr),
		.digit(ziffer_out2), .za(analyse[2]));
	es24_zaehler z3(.reset(reset), .clk(clk),
		.init(time12), .digit_time(data[3]),
		.add_enb(add), .sub_enb(sub), .carry_enb(pot09),
		.carry_in(carry[2]), .carry_out(carry[3]),
		.count_pulse(count_pulse), .clr(loeschen),
		.carry_clr(carry_clr),
		.digit(ziffer_out3), .za(analyse[3]));
	es24_zaehler z4(.reset(reset), .clk(clk),
		.init(time12), .digit_time(data[4]),
		.add_enb(add), .sub_enb(sub), .carry_enb(pot09),
		.carry_in(carry[3]), .carry_out(carry[4]),
		.count_pulse(count_pulse), .clr(loeschen),
		.carry_clr(carry_clr),
		.digit(ziffer_out4), .za(analyse[4]));
	es24_zaehler z5(.reset(reset), .clk(clk),
		.init(time12), .digit_time(data[5]),
		.add_enb(add), .sub_enb(sub), .carry_enb(pot09),
		.carry_in(carry[4]), .carry_out(carry[5]),
		.count_pulse(count_pulse), .clr(loeschen),
		.carry_clr(carry_clr),
		.digit(ziffer_out5), .za(analyse[5]));
	es24_zaehler z6(.reset(reset), .clk(clk),
		.init(time12), .digit_time(data[6]),
		.add_enb(add), .sub_enb(sub), .carry_enb(pot09),
		.carry_in(carry[5]), .carry_out(carry[6]),
		.count_pulse(count_pulse), .clr(loeschen),
		.carry_clr(carry_clr),
		.digit(ziffer_out6), .za(analyse[6]));

	es24_zaehler z7(.reset(reset), .clk(clk),
		.init(time12), .digit_time(data[7]),
		.add_enb(add), .sub_enb(sub), .carry_enb(pot09),
		.carry_in(carry[6]), .carry_out(carry[7]),
		.count_pulse(count_pulse), .clr(loeschen),
		.carry_clr(carry_clr),
		.digit(ziffer_out7), .za(analyse[7]));
	es24_zaehler z8(.reset(reset), .clk(clk),
		.init(time12), .digit_time(data[8]),
		.add_enb(add), .sub_enb(sub), .carry_enb(pot09),
		.carry_in(carry[7]), .carry_out(carry[8]),
		.count_pulse(count_pulse), .clr(loeschen),
		.carry_clr(carry_clr),
		.digit(ziffer_out8), .za(analyse[8]));
	es24_zaehler z9(.reset(reset), .clk(clk),
		.init(time12), .digit_time(data[9]),
		.add_enb(add), .sub_enb(sub), .carry_enb(pot09),
		.carry_in(carry[8]), .carry_out(carry[9]),
		.count_pulse(count_pulse), .clr(loeschen),
		.carry_clr(carry_clr),
		.digit(ziffer_out9), .za(analyse[9]));
	es24_zaehler z10(.reset(reset), .clk(clk),
		.init(time12), .digit_time(data[10]),
		.add_enb(add), .sub_enb(sub), .carry_enb(pot09),
		.carry_in(carry[9]), .carry_out(carry[10]),
		.count_pulse(count_pulse), .clr(loeschen),
		.carry_clr(carry_clr),
		.digit(ziffer_out10), .za(analyse[10]));
	es24_zaehler z11(.reset(reset), .clk(clk),
		.init(time12), .digit_time(data[11]),
		.add_enb(add), .sub_enb(sub), .carry_enb(pot09),
		.carry_in(carry[10]), .carry_out(carry[11]),
		.count_pulse(count_pulse), .clr(loeschen),
		.carry_clr(carry_clr),
		.digit(ziffer_out11), .za(analyse[11]));
	es24_zaehler z12(.reset(reset), .clk(clk),
		.init(time12), .digit_time(data[12]),
		.add_enb(add), .sub_enb(sub), .carry_enb(pot09),
		.carry_in(carry[11]), .carry_out(carry[12]),
		.count_pulse(count_pulse), .clr(loeschen),
		.carry_clr(carry_clr),
		.digit(ziffer_out12), .za(analyse[12]));
endmodule

module es24_zaehler(reset, clk,
	init, digit_time,
	add_enb, sub_enb, carry_enb,
	carry_in, carry_out,
	count_pulse,
	clr, carry_clr,
	digit,
	za
);
	input wire reset;
	input wire clk;
	input wire init;
	input wire digit_time;
	input wire add_enb;
	input wire sub_enb;
	input wire carry_enb;
	input wire carry_in;
	output wire carry_out;
	input wire count_pulse;
	input wire clr;
	input wire carry_clr;
	output reg [0:5] digit;
	output wire za;

	initial digit = 0;

	wire clr_pulse;
	edgedet e1(reset, clk, clr, clr_pulse);
	always @(posedge clk) begin
		if(clr_pulse)
			// TODO: how does this work?
			digit <= 6'b000011;
	end

	// R61
	reg digit_state;	// need better name
	always @(posedge clk) begin
		if(digit_time)	// R62
			digit_state <= 1;
		if(init)
			digit_state <= 0;
	end

	// R62
	wire sub_count = sub_enb & ~digit_state;
	// R63
	wire add_count = add_enb & digit_state;
	wire cry_count = carry_enb & carry_in;
	// R64
	wire count = (add_count | sub_count | cry_count) & count_pulse;
	// R64-R70 - Ring counter
	always @(posedge clk) begin
		if(count)
			digit[0:4] <= 0;
		if(digit_count[0]) digit[1] <= 1;
		if(digit_count[1]) digit[2] <= 1;
		if(digit_count[2]) digit[3] <= 1;
		if(digit_count[3]) digit[4] <= 1;
		if(digit_count[4]) digit[0] <= 1;
		if(digit_count[4]) digit[5] <= ~digit[5];
	end
	wire [0:5] digit_count;
	edgedet e2(clk, reset, ~digit[0], digit_count[0]);
	edgedet e3(clk, reset, ~digit[1], digit_count[1]);
	edgedet e4(clk, reset, ~digit[2], digit_count[2]);
	edgedet e5(clk, reset, ~digit[3], digit_count[3]);
	edgedet e6(clk, reset, ~digit[4], digit_count[4]);
	edgedet e7(clk, reset, ~digit[5], digit_count[5]);
	// have to keep this signal up for some time until
	// carry clear is through
	reg [4:0] carry_dly;
	always @(posedge clk)
		carry_dly <= { carry_dly[3:0], digit_count[5] };
	// R71 - Uebertrag
	reg carry;
	always @(posedge clk) begin
		if(carry_clr)
			carry <= 0;
		if(carry_dly[4])
			carry <= 1;
	end
	// R72 - carry out
	assign carry_out = carry;
	// R72 - zaehleranalyse
	assign za = digit[4] & digit[5];
endmodule

