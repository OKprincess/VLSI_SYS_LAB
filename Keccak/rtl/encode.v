// ==================================================
//	[ VLSISYS Lab. ]
//	* Author		: Woong Choi (woongchoi@sm.ac.kr)
//	* Filename		: encode.v
//	* Date			: 2025-05-08 00:35:45
//	* Description	: 
// ==================================================

module encode
(	
	output reg	[63:0]		o_obytes,
	output reg				o_obytes_valid,
	output reg				o_done,
	input		[23:0]		i_coeffs,
	input					i_coeffs_valid,
	input		[3:0]		i_l,
	input					i_clk,
	input					i_rstn
);

// --------------------------------------------------
//	FSM (Control)
// --------------------------------------------------
	localparam	S_IDLE		= 2'd0  ;
	localparam	S_COMP		= 2'd1  ;
	localparam	S_DONE		= 2'd2  ;

	reg			[1:0]		c_state;
	reg			[1:0]		n_state;

	// State Register
	always @(posedge i_clk or negedge i_rstn) begin
		if(!i_rstn) begin
			c_state	<= S_IDLE;
		end else begin
			c_state	<= n_state;
		end
	end

	// Next State Logic
	always @(*) begin
		case(c_state)
			S_IDLE	: n_state = (i_coeffs_valid)				? S_COMP : S_IDLE;
			S_COMP	: n_state = cnt_obytes == cnt_obytes_max	? S_DONE : S_COMP;
			S_DONE	: n_state = S_IDLE;
		endcase
	end

	// Output Logic
	always @(*) begin
		case(c_state)
			S_DONE		: o_done			= 1;
			default		: o_done			= 0;
		endcase
	end

// --------------------------------------------------
//	Flow Control
// --------------------------------------------------
	reg			[6:0]		cnt_coeffs;
	reg			[5:0]		cnt_obytes;
	reg			[5:0]		cnt_obytes_max;

	always @(posedge i_clk or negedge i_rstn) begin
		if (!i_rstn) begin
			cnt_coeffs <= 0;
		end else begin
			case (c_state)
				S_COMP		: begin
					case (i_l)
						4'd1	:	cnt_coeffs <= cnt_coeffs +  2 >= 64 ? cnt_coeffs +  2 - 64 : cnt_coeffs +  2;
						4'd4	:	cnt_coeffs <= cnt_coeffs +  8 >= 64 ? cnt_coeffs +  8 - 64 : cnt_coeffs +  8;
						4'd5	:	cnt_coeffs <= cnt_coeffs + 10 >= 64 ? cnt_coeffs + 10 - 64 : cnt_coeffs + 10;
						4'd10	:	cnt_coeffs <= cnt_coeffs + 20 >= 64 ? cnt_coeffs + 20 - 64 : cnt_coeffs + 20;
						4'd11	:	cnt_coeffs <= cnt_coeffs + 22 >= 64 ? cnt_coeffs + 22 - 64 : cnt_coeffs + 22;
						4'd12	:	cnt_coeffs <= cnt_coeffs + 24 >= 64 ? cnt_coeffs + 24 - 64 : cnt_coeffs + 24;
						default	:	cnt_coeffs <= 0;
					endcase
				end
				default		: cnt_coeffs	<= 0;
			endcase
		end
	end

	always @(posedge i_clk or negedge i_rstn) begin
		if (!i_rstn) begin
			o_obytes_valid <= 0;
		end else begin
			case (c_state)
				S_COMP		: begin
					case (i_l)
						4'd1	:	o_obytes_valid <= cnt_coeffs +  2 >= 64 ? 1 : 0;
						4'd4	:	o_obytes_valid <= cnt_coeffs +  8 >= 64 ? 1 : 0;
						4'd5	:	o_obytes_valid <= cnt_coeffs + 10 >= 64 ? 1 : 0;
						4'd10	:	o_obytes_valid <= cnt_coeffs + 20 >= 64 ? 1 : 0;
						4'd11	:	o_obytes_valid <= cnt_coeffs + 22 >= 64 ? 1 : 0;
						4'd12	:	o_obytes_valid <= cnt_coeffs + 24 >= 64 ? 1 : 0;
						default	:	o_obytes_valid <= 0;
					endcase
				end
				default		: o_obytes_valid <= 0;
			endcase
		end
	end

	always @(*) begin
		case (i_l)
			4'd1	:	cnt_obytes_max	= 256* 1/64;
			4'd4	:	cnt_obytes_max	= 256* 4/64;
			4'd5	:	cnt_obytes_max	= 256* 5/64;
			4'd10	:	cnt_obytes_max	= 256*10/64;
			4'd11	:	cnt_obytes_max	= 256*11/64;
			4'd12	:	cnt_obytes_max	= 256*12/64;
			default	:	cnt_obytes_max	= 256*12/64;
		endcase
	end

	always @(posedge i_clk or negedge i_rstn) begin
		if (!i_rstn) begin
			cnt_obytes	<= 0;
		end else begin
			case (c_state)
				S_IDLE	: cnt_obytes <= 0;
				S_COMP	: cnt_obytes <= o_obytes_valid ? cnt_obytes + 1 : cnt_obytes;
				default	: cnt_obytes <= cnt_obytes;
			endcase
		end
	end

	reg		[23:0]		coeff_rev;
	reg		[71:0]		coeff_reg;

	always @(*) begin
		case (i_l)
			4'd1	:  coeff_rev = {22'd0,	i_coeffs[12], i_coeffs[ 0]};
			4'd4	:  coeff_rev = {16'd0,	i_coeffs[12], i_coeffs[13], i_coeffs[14], i_coeffs[15], i_coeffs[ 0], i_coeffs[ 1], i_coeffs[ 2], i_coeffs[ 3]};
			4'd5	:  coeff_rev = {14'd0,	i_coeffs[12], i_coeffs[13], i_coeffs[14], i_coeffs[15], i_coeffs[16], i_coeffs[ 0], i_coeffs[ 1], i_coeffs[ 2], i_coeffs[ 3], i_coeffs[ 4]};
			4'd10	:  coeff_rev = {4'd0,	i_coeffs[12], i_coeffs[13], i_coeffs[14], i_coeffs[15], i_coeffs[16], i_coeffs[17], i_coeffs[18], i_coeffs[19], i_coeffs[20], i_coeffs[21], i_coeffs[ 0], i_coeffs[ 1], i_coeffs[ 2], i_coeffs[ 3], i_coeffs[ 4], i_coeffs[ 5], i_coeffs[ 6], i_coeffs[ 7], i_coeffs[ 8], i_coeffs[ 9]};
			4'd11	:  coeff_rev = {2'd0,	i_coeffs[12], i_coeffs[13], i_coeffs[14], i_coeffs[15], i_coeffs[16], i_coeffs[17], i_coeffs[18], i_coeffs[19], i_coeffs[20], i_coeffs[21], i_coeffs[22], i_coeffs[ 0], i_coeffs[ 1], i_coeffs[ 2], i_coeffs[ 3], i_coeffs[ 4], i_coeffs[ 5], i_coeffs[ 6], i_coeffs[ 7], i_coeffs[ 8], i_coeffs[ 9], i_coeffs[10]};
			4'd12	:  coeff_rev = {		i_coeffs[12], i_coeffs[13], i_coeffs[14], i_coeffs[15], i_coeffs[16], i_coeffs[17], i_coeffs[18], i_coeffs[19], i_coeffs[20], i_coeffs[21], i_coeffs[22], i_coeffs[23], i_coeffs[ 0], i_coeffs[ 1], i_coeffs[ 2], i_coeffs[ 3], i_coeffs[ 4], i_coeffs[ 5], i_coeffs[ 6], i_coeffs[ 7], i_coeffs[ 8], i_coeffs[ 9], i_coeffs[10], i_coeffs[11]};
			default	:  coeff_rev = 24'd0;
		endcase
	end

	always @(posedge i_clk or negedge i_rstn) begin
		if (!i_rstn || c_state == S_DONE) begin
			coeff_reg	<= 0;
		end else begin
			case(i_l)
				4'd1	:  coeff_reg[63:0] <= {coeff_reg[63- 2:0], coeff_rev[ 1:0]};
				4'd4	:  coeff_reg[63:0] <= {coeff_reg[63- 8:0], coeff_rev[ 7:0]};
				4'd5	:  coeff_reg[69:0] <= {coeff_reg[69-10:0], coeff_rev[ 9:0]};
				4'd10	:  coeff_reg[59:0] <= {coeff_reg[59-20:0], coeff_rev[19:0]};
				4'd11	:  coeff_reg[65:0] <= {coeff_reg[65-22:0], coeff_rev[21:0]};
				4'd12	:  coeff_reg[71:0] <= {coeff_reg[71-24:0], coeff_rev[23:0]};
				default	:  coeff_reg       <= 0;
			endcase
		end
	end

	reg		[63:0]	obytes;
	always @(*) begin
		case (i_l)
			4'd1	: begin
				case (cnt_coeffs)
					7'd62	: obytes = {coeff_reg[ 0+ 2*31-1:0], coeff_rev[ 1-:64-62]};
					default	: obytes = 0;
				endcase
			end
			4'd4	: begin
				case (cnt_coeffs)
					7'd56	: obytes = {coeff_reg[ 0+ 8*7-1:0], coeff_rev[ 7-:64-56]};
					default	: obytes = 0;
				endcase
			end
			4'd5	: begin
				case (cnt_coeffs)
					7'd60	: obytes = {coeff_reg[ 0+10*6-1:0], coeff_rev[ 9-:64-60]};
					7'd56	: obytes = {coeff_reg[ 6+10*5-1:0], coeff_rev[ 9-:64-56]};
					7'd62	: obytes = {coeff_reg[ 2+10*6-1:0], coeff_rev[ 9-:64-62]};
					7'd58	: obytes = {coeff_reg[ 8+10*5-1:0], coeff_rev[ 9-:64-58]};
					7'd54	: obytes = {coeff_reg[ 4+10*5-1:0], coeff_rev[ 9-:64-54]};
					default	: obytes = 0;
				endcase
			end
			4'd10	: begin
				case (cnt_coeffs)
					7'd60	: obytes = {coeff_reg[ 0+20*3-1:0], coeff_rev[19-:64-60]};
					7'd56	: obytes = {coeff_reg[16+20*2-1:0], coeff_rev[19-:64-56]};
					7'd52	: obytes = {coeff_reg[12+20*2-1:0], coeff_rev[19-:64-52]};
					7'd48	: obytes = {coeff_reg[ 8+20*2-1:0], coeff_rev[19-:64-48]};
					7'd44	: obytes = {coeff_reg[ 4+20*2-1:0], coeff_rev[19-:64-44]};
					default	: obytes = 0;
				endcase
			end
			4'd11	: begin
				case (cnt_coeffs)
					7'd44	: obytes = {coeff_reg[ 0+22*2-1:0], coeff_rev[21-:64-44]};
					7'd46	: obytes = {coeff_reg[ 2+22*2-1:0], coeff_rev[21-:64-46]};
					7'd48	: obytes = {coeff_reg[ 4+22*2-1:0], coeff_rev[21-:64-48]};
					7'd50	: obytes = {coeff_reg[ 6+22*2-1:0], coeff_rev[21-:64-50]};
					7'd52	: obytes = {coeff_reg[ 8+22*2-1:0], coeff_rev[21-:64-52]};
					7'd54	: obytes = {coeff_reg[10+22*2-1:0], coeff_rev[21-:64-54]};
					7'd56	: obytes = {coeff_reg[12+22*2-1:0], coeff_rev[21-:64-56]};
					7'd58	: obytes = {coeff_reg[14+22*2-1:0], coeff_rev[21-:64-58]};
					7'd60	: obytes = {coeff_reg[16+22*2-1:0], coeff_rev[21-:64-60]};
					7'd62	: obytes = {coeff_reg[18+22*2-1:0], coeff_rev[21-:64-62]};
					7'd42	: obytes = {coeff_reg[20+22*1-1:0], coeff_rev[21-:64-42]};
					default	: obytes = 0;
				endcase
			end
			4'd12	: begin
				case (cnt_coeffs)
					7'd48	: obytes = {coeff_reg[ 0+24*2-1:0], coeff_rev[23-:64-48]};
					7'd56	: obytes = {coeff_reg[ 8+24*2-1:0], coeff_rev[23-:64-56]};
					7'd40	: obytes = {coeff_reg[16+24*1-1:0], coeff_rev[23-:64-40]};
					default	: obytes = 0;
				endcase
			end
			default	: obytes = 0;
		endcase
	end

	always @(posedge i_clk or negedge i_rstn) begin
		if (!i_rstn) begin
			o_obytes <= 0;
		end else begin
			o_obytes <= {	obytes[56], obytes[57], obytes[58], obytes[59], obytes[60], obytes[61], obytes[62], obytes[63],
							obytes[48], obytes[49], obytes[50], obytes[51], obytes[52], obytes[53], obytes[54], obytes[55],
							obytes[40], obytes[41], obytes[42], obytes[43], obytes[44], obytes[45], obytes[46], obytes[47],
							obytes[32], obytes[33], obytes[34], obytes[35], obytes[36], obytes[37], obytes[38], obytes[39],
							obytes[24], obytes[25], obytes[26], obytes[27], obytes[28], obytes[29], obytes[30], obytes[31],
							obytes[16], obytes[17], obytes[18], obytes[19], obytes[20], obytes[21], obytes[22], obytes[23],
							obytes[ 8], obytes[ 9], obytes[10], obytes[11], obytes[12], obytes[13], obytes[14], obytes[15],
							obytes[ 0], obytes[ 1], obytes[ 2], obytes[ 3], obytes[ 4], obytes[ 5], obytes[ 6], obytes[ 7]};
		end
	end

	`ifdef DEBUG
	reg		[12*256-1:0]	o_obytes_debug;
	always @(posedge i_clk or negedge i_rstn) begin
		if (!i_rstn || c_state == S_IDLE) begin
			o_obytes_debug	<= 0;
		end else begin
			if (o_obytes_valid) begin
				o_obytes_debug	<= {o_obytes_debug[12*256-1-64:0], o_obytes};
			end else begin
				o_obytes_debug	<= o_obytes_debug;
			end
		end
	end
	`endif

endmodule
