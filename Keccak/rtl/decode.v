// ==================================================
//	[ VLSISYS Lab. ]
//	* Author		: Woong Choi (woongchoi@sm.ac.kr)
//	* Filename		: decode.v
//	* Description	: 
// ==================================================

module decode
(	
	output reg	[63:0]		o_coeffs,
	output reg				o_coeffs_valid,
	output reg				o_ibytes_ready,
	output reg				o_done,
	input		[63:0]		i_ibytes,
	input					i_ibytes_valid,
	input		[3:0]		i_l,
	input					i_clk,
	input					i_rstn
);

// --------------------------------------------------
//	FSM (Control)
// --------------------------------------------------
	localparam	S_IDLE		= 2'd0  ;
	localparam	S_COMP_0	= 2'd1  ;
	localparam	S_COMP_1	= 2'd2  ;
	localparam	S_DONE		= 2'd3  ;

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
			S_IDLE		: n_state = (i_ibytes_valid)				? S_COMP_1	: S_IDLE;
			S_COMP_0	,
			S_COMP_1	: n_state = cnt_coeffs == cnt_coeffs_max	? S_DONE	: 
									offset + offset_base > 64		? S_COMP_0	: S_COMP_1;
			S_DONE		: n_state = S_IDLE;
		endcase
	end

	// Output Logic
	always @(*) begin
		case(c_state)
			S_DONE		: o_done			= 1;
			default		: o_done			= 0;
		endcase
	end

	always @(*) begin
		case(n_state)
			S_IDLE		,
			S_COMP_1	: o_ibytes_ready	= n_state == S_COMP_0 ? 0 : 1;
			default		: o_ibytes_ready	= 0;
		endcase
	end

	always @(posedge i_clk or negedge i_rstn) begin
		if (!i_rstn) begin
			o_coeffs_valid	<= 0;
		end else begin
			case(c_state)
				S_COMP_0	, 
				S_COMP_1	: o_coeffs_valid	<= 1;
				default		: o_coeffs_valid	<= 0;
			endcase
		end
	end
	
//	       i_l = 1, 4, 5, 10, 11, 12
//	64 mod i_l = 0, 0, 4, 4, 9, 4
// --------------------------------------------------
//	Flow Control
// --------------------------------------------------
//	reg			[5:0]		cnt_ibytes;
	reg			[5:0]		cnt_coeffs;
	reg			[5:0]		cnt_coeffs_max;
	reg			[6:0]		offset_base;
	reg			[6:0]		offset;

	always @(*) begin
		case (i_l)
			4'd1	,
			4'd4	:	offset_base	= 0;
			4'd11	:	offset_base	= 9;
			default	:	offset_base	= 4;
		endcase
	end

	always @(*) begin
		case (i_l)
			4'd1	:	cnt_coeffs_max	=  3;
			4'd4	:	cnt_coeffs_max	= 15;
			4'd5	:	cnt_coeffs_max	= 21;
			4'd10	:	cnt_coeffs_max	= 42;
			default	:	cnt_coeffs_max	= 51;
		endcase
	end

	always @(posedge i_clk or negedge i_rstn) begin
		if (!i_rstn) begin
			offset	<= 0;
		end else begin
			case (c_state)
				S_IDLE		: offset	<= 0;
				S_COMP_0	,
				S_COMP_1	: offset	<= offset + offset_base > 64 ? offset - (64 - offset_base) : offset + offset_base;
				default		: offset	<= offset;
			endcase
		end
	end

//	always @(posedge i_clk or negedge i_rstn) begin
//		if (!i_rstn) begin
//			cnt_ibytes	<= 0;
//		end else begin
//			case (c_state)
//				S_IDLE		, 
//				S_DONE		: cnt_ibytes	<= 0;
//				S_COMP_1	: cnt_ibytes	<= cnt_ibytes + 1;
//				default		: cnt_ibytes	<= cnt_ibytes;
//			endcase
//		end
//	end

	always @(posedge i_clk or negedge i_rstn) begin
		if (!i_rstn) begin
			cnt_coeffs	<= 0;
		end else begin
			case (c_state)
				S_COMP_0	, 
				S_COMP_1	: cnt_coeffs	<= cnt_coeffs < cnt_coeffs_max ? cnt_coeffs + 1 : cnt_coeffs;
				default		: cnt_coeffs	<= 0;
			endcase
		end
	end
// --------------------------------------------------
//	Input Byte With Byte-Wise Reversed Order
// --------------------------------------------------
	wire		[63:0]		ibytes_bwr;	
	genvar					i;
	generate
		for (i=0; i<8; i=i+1) begin
			assign	ibytes_bwr[64-1-8*i-:8] = { i_ibytes[64-1-8*i-7], i_ibytes[64-1-8*i-6],
												i_ibytes[64-1-8*i-5], i_ibytes[64-1-8*i-4],
												i_ibytes[64-1-8*i-3], i_ibytes[64-1-8*i-2],
												i_ibytes[64-1-8*i-1], i_ibytes[64-1-8*i-0]};
		end
	endgenerate

	reg			[63:0]		ibytes_bwr_reg;	
	always @(posedge i_clk or negedge i_rstn) begin
		if (!i_rstn) begin
			ibytes_bwr_reg <= 0;	
		end else begin
			if (n_state == S_COMP_0) begin
				ibytes_bwr_reg <= ibytes_bwr_reg;
			end else begin
				ibytes_bwr_reg <= ibytes_bwr;
			end
		end
	end

	reg			[63:0]		ibytes_concat;	
	always @(*) begin
		case(offset)
			7'd0	: ibytes_concat	= {                      ibytes_bwr[63: 0]};	
			7'd1	: ibytes_concat	= {ibytes_bwr_reg[ 0:0], ibytes_bwr[63: 1]};	
			7'd2	: ibytes_concat	= {ibytes_bwr_reg[ 1:0], ibytes_bwr[63: 2]};	
			7'd3	: ibytes_concat	= {ibytes_bwr_reg[ 2:0], ibytes_bwr[63: 3]};	
			7'd4	: ibytes_concat	= {ibytes_bwr_reg[ 3:0], ibytes_bwr[63: 4]};	
			7'd5	: ibytes_concat	= {ibytes_bwr_reg[ 4:0], ibytes_bwr[63: 5]};	
			7'd6	: ibytes_concat	= {ibytes_bwr_reg[ 5:0], ibytes_bwr[63: 6]};	
			7'd7	: ibytes_concat	= {ibytes_bwr_reg[ 6:0], ibytes_bwr[63: 7]};	
			7'd8	: ibytes_concat	= {ibytes_bwr_reg[ 7:0], ibytes_bwr[63: 8]};	
			7'd9	: ibytes_concat	= {ibytes_bwr_reg[ 8:0], ibytes_bwr[63: 9]};	
			7'd10	: ibytes_concat	= {ibytes_bwr_reg[ 9:0], ibytes_bwr[63:10]};	
			7'd11	: ibytes_concat	= {ibytes_bwr_reg[10:0], ibytes_bwr[63:11]};	
			7'd12	: ibytes_concat	= {ibytes_bwr_reg[11:0], ibytes_bwr[63:12]};	
			7'd13	: ibytes_concat	= {ibytes_bwr_reg[12:0], ibytes_bwr[63:13]};	
			7'd14	: ibytes_concat	= {ibytes_bwr_reg[13:0], ibytes_bwr[63:14]};	
			7'd15	: ibytes_concat	= {ibytes_bwr_reg[14:0], ibytes_bwr[63:15]};	
			7'd16	: ibytes_concat	= {ibytes_bwr_reg[15:0], ibytes_bwr[63:16]};	
			7'd17	: ibytes_concat	= {ibytes_bwr_reg[16:0], ibytes_bwr[63:17]};	
			7'd18	: ibytes_concat	= {ibytes_bwr_reg[17:0], ibytes_bwr[63:18]};	
			7'd19	: ibytes_concat	= {ibytes_bwr_reg[18:0], ibytes_bwr[63:19]};	
			7'd20	: ibytes_concat	= {ibytes_bwr_reg[19:0], ibytes_bwr[63:20]};	
			7'd21	: ibytes_concat	= {ibytes_bwr_reg[20:0], ibytes_bwr[63:21]};	
			7'd22	: ibytes_concat	= {ibytes_bwr_reg[21:0], ibytes_bwr[63:22]};	
			7'd23	: ibytes_concat	= {ibytes_bwr_reg[22:0], ibytes_bwr[63:23]};	
			7'd24	: ibytes_concat	= {ibytes_bwr_reg[23:0], ibytes_bwr[63:24]};	
			7'd25	: ibytes_concat	= {ibytes_bwr_reg[24:0], ibytes_bwr[63:25]};	
			7'd26	: ibytes_concat	= {ibytes_bwr_reg[25:0], ibytes_bwr[63:26]};	
			7'd27	: ibytes_concat	= {ibytes_bwr_reg[26:0], ibytes_bwr[63:27]};	
			7'd28	: ibytes_concat	= {ibytes_bwr_reg[27:0], ibytes_bwr[63:28]};	
			7'd29	: ibytes_concat	= {ibytes_bwr_reg[28:0], ibytes_bwr[63:29]};	
			7'd30	: ibytes_concat	= {ibytes_bwr_reg[29:0], ibytes_bwr[63:30]};	
			7'd31	: ibytes_concat	= {ibytes_bwr_reg[30:0], ibytes_bwr[63:31]};	
			7'd32	: ibytes_concat	= {ibytes_bwr_reg[31:0], ibytes_bwr[63:32]};	
			7'd33	: ibytes_concat	= {ibytes_bwr_reg[32:0], ibytes_bwr[63:33]};	
			7'd34	: ibytes_concat	= {ibytes_bwr_reg[33:0], ibytes_bwr[63:34]};	
			7'd35	: ibytes_concat	= {ibytes_bwr_reg[34:0], ibytes_bwr[63:35]};	
			7'd36	: ibytes_concat	= {ibytes_bwr_reg[35:0], ibytes_bwr[63:36]};	
			7'd37	: ibytes_concat	= {ibytes_bwr_reg[36:0], ibytes_bwr[63:37]};	
			7'd38	: ibytes_concat	= {ibytes_bwr_reg[37:0], ibytes_bwr[63:38]};	
			7'd39	: ibytes_concat	= {ibytes_bwr_reg[38:0], ibytes_bwr[63:39]};	
			7'd40	: ibytes_concat	= {ibytes_bwr_reg[39:0], ibytes_bwr[63:40]};	
			7'd41	: ibytes_concat	= {ibytes_bwr_reg[40:0], ibytes_bwr[63:41]};	
			7'd42	: ibytes_concat	= {ibytes_bwr_reg[41:0], ibytes_bwr[63:42]};	
			7'd43	: ibytes_concat	= {ibytes_bwr_reg[42:0], ibytes_bwr[63:43]};	
			7'd44	: ibytes_concat	= {ibytes_bwr_reg[43:0], ibytes_bwr[63:44]};	
			7'd45	: ibytes_concat	= {ibytes_bwr_reg[44:0], ibytes_bwr[63:45]};	
			7'd46	: ibytes_concat	= {ibytes_bwr_reg[45:0], ibytes_bwr[63:46]};	
			7'd47	: ibytes_concat	= {ibytes_bwr_reg[46:0], ibytes_bwr[63:47]};	
			7'd48	: ibytes_concat	= {ibytes_bwr_reg[47:0], ibytes_bwr[63:48]};	
			7'd49	: ibytes_concat	= {ibytes_bwr_reg[48:0], ibytes_bwr[63:49]};	
			7'd50	: ibytes_concat	= {ibytes_bwr_reg[49:0], ibytes_bwr[63:50]};	
			7'd51	: ibytes_concat	= {ibytes_bwr_reg[50:0], ibytes_bwr[63:51]};	
			7'd52	: ibytes_concat	= {ibytes_bwr_reg[51:0], ibytes_bwr[63:52]};	
			7'd53	: ibytes_concat	= {ibytes_bwr_reg[52:0], ibytes_bwr[63:53]};	
			7'd54	: ibytes_concat	= {ibytes_bwr_reg[53:0], ibytes_bwr[63:54]};	
			7'd55	: ibytes_concat	= {ibytes_bwr_reg[54:0], ibytes_bwr[63:55]};	
			7'd56	: ibytes_concat	= {ibytes_bwr_reg[55:0], ibytes_bwr[63:56]};	
			7'd57	: ibytes_concat	= {ibytes_bwr_reg[56:0], ibytes_bwr[63:57]};	
			7'd58	: ibytes_concat	= {ibytes_bwr_reg[57:0], ibytes_bwr[63:58]};	
			7'd59	: ibytes_concat	= {ibytes_bwr_reg[58:0], ibytes_bwr[63:59]};	
			7'd60	: ibytes_concat	= {ibytes_bwr_reg[59:0], ibytes_bwr[63:60]};	
			7'd61	: ibytes_concat	= {ibytes_bwr_reg[60:0], ibytes_bwr[63:61]};	
			7'd62	: ibytes_concat	= {ibytes_bwr_reg[61:0], ibytes_bwr[63:62]};	
			7'd63	: ibytes_concat	= {ibytes_bwr_reg[62:0], ibytes_bwr[63:63]};	
			7'd64	: ibytes_concat	= {ibytes_bwr_reg[63:0]                   };	
			default	: ibytes_concat	= ibytes_bwr;
		endcase
	end
// --------------------------------------------------
//	Output Coeff
// --------------------------------------------------
	always @(posedge i_clk or negedge i_rstn) begin
		if (!i_rstn) begin
			o_coeffs	<= 0;
		end else begin
			case (c_state)
				S_COMP_0	,
				S_COMP_1	: begin
					case (i_l)
						4'd4	: o_coeffs	<= {ibytes_concat[60], ibytes_concat[61], ibytes_concat[62], ibytes_concat[63],
												ibytes_concat[56], ibytes_concat[57], ibytes_concat[58], ibytes_concat[59],
												ibytes_concat[52], ibytes_concat[53], ibytes_concat[54], ibytes_concat[55],
												ibytes_concat[48], ibytes_concat[49], ibytes_concat[50], ibytes_concat[51],
												ibytes_concat[44], ibytes_concat[45], ibytes_concat[46], ibytes_concat[47],
												ibytes_concat[40], ibytes_concat[41], ibytes_concat[42], ibytes_concat[43],
												ibytes_concat[36], ibytes_concat[37], ibytes_concat[38], ibytes_concat[39],
												ibytes_concat[32], ibytes_concat[33], ibytes_concat[34], ibytes_concat[35],
												ibytes_concat[28], ibytes_concat[29], ibytes_concat[30], ibytes_concat[31],
												ibytes_concat[24], ibytes_concat[25], ibytes_concat[26], ibytes_concat[27],
												ibytes_concat[20], ibytes_concat[21], ibytes_concat[22], ibytes_concat[23],
												ibytes_concat[16], ibytes_concat[17], ibytes_concat[18], ibytes_concat[19],
												ibytes_concat[12], ibytes_concat[13], ibytes_concat[14], ibytes_concat[15],
												ibytes_concat[ 8], ibytes_concat[ 9], ibytes_concat[10], ibytes_concat[11],
												ibytes_concat[ 4], ibytes_concat[ 5], ibytes_concat[ 6], ibytes_concat[ 7],
												ibytes_concat[ 0], ibytes_concat[ 1], ibytes_concat[ 2], ibytes_concat[ 3]};

						4'd5	: o_coeffs	<= {ibytes_concat[59], ibytes_concat[60], ibytes_concat[61], ibytes_concat[62], ibytes_concat[63],
												ibytes_concat[54], ibytes_concat[55], ibytes_concat[56], ibytes_concat[57], ibytes_concat[58],
												ibytes_concat[49], ibytes_concat[50], ibytes_concat[51], ibytes_concat[52], ibytes_concat[53],
												ibytes_concat[44], ibytes_concat[45], ibytes_concat[46], ibytes_concat[47], ibytes_concat[48],
												ibytes_concat[39], ibytes_concat[40], ibytes_concat[41], ibytes_concat[42], ibytes_concat[43],
												ibytes_concat[34], ibytes_concat[35], ibytes_concat[36], ibytes_concat[37], ibytes_concat[38],
												ibytes_concat[29], ibytes_concat[30], ibytes_concat[31], ibytes_concat[32], ibytes_concat[33],
												ibytes_concat[24], ibytes_concat[25], ibytes_concat[26], ibytes_concat[27], ibytes_concat[28],
												ibytes_concat[19], ibytes_concat[20], ibytes_concat[21], ibytes_concat[22], ibytes_concat[23],
												ibytes_concat[14], ibytes_concat[15], ibytes_concat[16], ibytes_concat[17], ibytes_concat[18],
												ibytes_concat[ 9], ibytes_concat[10], ibytes_concat[11], ibytes_concat[12], ibytes_concat[13],
												ibytes_concat[ 4], ibytes_concat[ 5], ibytes_concat[ 6], ibytes_concat[ 7], ibytes_concat[ 8],
												4'b0};

						4'd10	: o_coeffs	<= {ibytes_concat[54], ibytes_concat[55], ibytes_concat[56], ibytes_concat[57], ibytes_concat[58], ibytes_concat[59], ibytes_concat[60], ibytes_concat[61], ibytes_concat[62], ibytes_concat[63],
												ibytes_concat[44], ibytes_concat[45], ibytes_concat[46], ibytes_concat[47], ibytes_concat[48], ibytes_concat[49], ibytes_concat[50], ibytes_concat[51], ibytes_concat[52], ibytes_concat[53],
												ibytes_concat[34], ibytes_concat[35], ibytes_concat[36], ibytes_concat[37], ibytes_concat[38], ibytes_concat[39], ibytes_concat[40], ibytes_concat[41], ibytes_concat[42], ibytes_concat[43],
												ibytes_concat[24], ibytes_concat[25], ibytes_concat[26], ibytes_concat[27], ibytes_concat[28], ibytes_concat[29], ibytes_concat[30], ibytes_concat[31], ibytes_concat[32], ibytes_concat[33],
												ibytes_concat[14], ibytes_concat[15], ibytes_concat[16], ibytes_concat[17], ibytes_concat[18], ibytes_concat[19], ibytes_concat[20], ibytes_concat[21], ibytes_concat[22], ibytes_concat[23],
												ibytes_concat[ 4], ibytes_concat[ 5], ibytes_concat[ 6], ibytes_concat[ 7], ibytes_concat[ 8], ibytes_concat[ 9], ibytes_concat[10], ibytes_concat[11], ibytes_concat[12], ibytes_concat[13],
												4'b0};


						4'd11	: o_coeffs	<= {ibytes_concat[53], ibytes_concat[54], ibytes_concat[55], ibytes_concat[56], ibytes_concat[57], ibytes_concat[58], ibytes_concat[59], ibytes_concat[60], ibytes_concat[61], ibytes_concat[62], ibytes_concat[63],
												ibytes_concat[42], ibytes_concat[43], ibytes_concat[44], ibytes_concat[45], ibytes_concat[46], ibytes_concat[47], ibytes_concat[48], ibytes_concat[49], ibytes_concat[50], ibytes_concat[51], ibytes_concat[52],
												ibytes_concat[31], ibytes_concat[32], ibytes_concat[33], ibytes_concat[34], ibytes_concat[35], ibytes_concat[36], ibytes_concat[37], ibytes_concat[38], ibytes_concat[39], ibytes_concat[40], ibytes_concat[41],
												ibytes_concat[20], ibytes_concat[21], ibytes_concat[22], ibytes_concat[23], ibytes_concat[24], ibytes_concat[25], ibytes_concat[26], ibytes_concat[27], ibytes_concat[28], ibytes_concat[29], ibytes_concat[30],
												ibytes_concat[ 9], ibytes_concat[10], ibytes_concat[11], ibytes_concat[12], ibytes_concat[13], ibytes_concat[14], ibytes_concat[15], ibytes_concat[16], ibytes_concat[17], ibytes_concat[18], ibytes_concat[19],
												9'b0};

						4'd12	: o_coeffs	<= {ibytes_concat[52], ibytes_concat[53], ibytes_concat[54], ibytes_concat[55], ibytes_concat[56], ibytes_concat[57], ibytes_concat[58], ibytes_concat[59], ibytes_concat[60], ibytes_concat[61], ibytes_concat[62], ibytes_concat[63], 
												ibytes_concat[40], ibytes_concat[41], ibytes_concat[42], ibytes_concat[43], ibytes_concat[44], ibytes_concat[45], ibytes_concat[46], ibytes_concat[47], ibytes_concat[48], ibytes_concat[49], ibytes_concat[50], ibytes_concat[51],
												ibytes_concat[28], ibytes_concat[29], ibytes_concat[30], ibytes_concat[31], ibytes_concat[32], ibytes_concat[33], ibytes_concat[34], ibytes_concat[35], ibytes_concat[36], ibytes_concat[37], ibytes_concat[38], ibytes_concat[39],
												ibytes_concat[16], ibytes_concat[17], ibytes_concat[18], ibytes_concat[19], ibytes_concat[20], ibytes_concat[21], ibytes_concat[22], ibytes_concat[23], ibytes_concat[24], ibytes_concat[25], ibytes_concat[26], ibytes_concat[27],
												ibytes_concat[ 4], ibytes_concat[ 5], ibytes_concat[ 6], ibytes_concat[ 7], ibytes_concat[ 8], ibytes_concat[ 9], ibytes_concat[10], ibytes_concat[11], ibytes_concat[12], ibytes_concat[13], ibytes_concat[14], ibytes_concat[15],
												4'b0};
						default	: o_coeffs	<=	ibytes_concat;
					endcase
				end
				default		: o_coeffs	<= o_coeffs;
			endcase
		end
	end

	`ifdef	DEBUG
	reg			[127:0]			ASCII_C_STATE;
	always @(*) begin
		case (c_state)
			S_IDLE	: ASCII_C_STATE = "S_IDLE  ";
			S_COMP_0: ASCII_C_STATE = "S_COMP_0";
			S_COMP_1: ASCII_C_STATE = "S_COMP_1";
			S_DONE	: ASCII_C_STATE = "S_DONE  ";
		endcase
	end

	reg			[12*256-1:0]	o_coeffs_debug;
	always @(posedge i_clk or negedge i_rstn) begin
		if (!i_rstn) begin
			o_coeffs_debug	<= 0;
		end else begin
			if (o_coeffs_valid) begin
				if (c_state != S_DONE) begin
					case (i_l)
						4'd1	: o_coeffs_debug[ 1*256-1-(cnt_coeffs-1)*64-:64] <= o_coeffs[63-:64];
						4'd4	: o_coeffs_debug[ 4*256-1-(cnt_coeffs-1)*64-:64] <= o_coeffs[63-:64];
						4'd5	: o_coeffs_debug[ 5*256-1-(cnt_coeffs-1)*60-:60] <= o_coeffs[63-:60];
						4'd10	: o_coeffs_debug[10*256-1-(cnt_coeffs-1)*60-:60] <= o_coeffs[63-:60];
						4'd11	: o_coeffs_debug[11*256-1-(cnt_coeffs-1)*55-:55] <= o_coeffs[63-:55];
						4'd12	: o_coeffs_debug[12*256-1-(cnt_coeffs-1)*60-:60] <= o_coeffs[63-:60];
						default	: o_coeffs_debug                                 <= 0;
					endcase
				end else begin
					case (i_l)
						4'd1	: o_coeffs_debug[ 1*256-1-(cnt_coeffs)*64-:64]   <= o_coeffs[63-:64];
						4'd4	: o_coeffs_debug[ 4*256-1-(cnt_coeffs)*64-:64]   <= o_coeffs[63-:64];
						4'd5	: o_coeffs_debug[ 5*256-1-(cnt_coeffs)*60-:20]   <= o_coeffs[63-:20];
						4'd10	: o_coeffs_debug[10*256-1-(cnt_coeffs)*60-:40]   <= o_coeffs[63-:40];
						4'd11	: o_coeffs_debug[11*256-1-(cnt_coeffs)*55-:11]   <= o_coeffs[63-:11];
						4'd12	: o_coeffs_debug[12*256-1-(cnt_coeffs)*60-:12]   <= o_coeffs[63-:12];
						default	: o_coeffs_debug                                 <= 0;
					endcase
				end
			end else begin
				o_coeffs_debug	<= 0;
			end
		end
	end

	`endif

endmodule
