// ==================================================
//	[ VLSISYS Lab. ]
//	* Author		: Woong Choi (woongchoi@sm.ac.kr)
//	* Filename		: cbd.v
//	* Description	: 
// ==================================================

`include	"configs.v"

module cbd
(	
	output reg	[47:0]		o_coeffs,
	output reg				o_coeffs_valid,
	output reg				o_ibytes_ready,
	output reg				o_done,
	input		[63:0]		i_ibytes,
	input					i_ibytes_valid,
	input		[1:0]		i_eta,
	input					i_clk,
	input					i_rstn
);

// --------------------------------------------------
//	FSM
// --------------------------------------------------
	localparam	S_IDLE		= 3'd0  ;
	localparam	S_ETA2		= 3'd1  ;
	localparam	S_ETA3_0	= 3'd2  ;
	localparam	S_ETA3_1	= 3'd3  ;
	localparam	S_ETA3_2	= 3'd4  ;
	localparam	S_DONE		= 3'd5  ;

	reg			[2:0]		c_state;
	reg			[2:0]		n_state;

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
			S_IDLE		: n_state = (i_ibytes_valid && i_eta == 2)	? S_ETA2	: 
									(i_ibytes_valid && i_eta == 3)	? S_ETA3_0	: S_IDLE;
			S_ETA2		: n_state = (cnt_coeffs == 15)				? S_DONE	: S_ETA2;
			S_ETA3_0	: n_state = (cnt_coeffs == 15)				? S_DONE	: S_ETA3_1;
			S_ETA3_1	: n_state = (cnt_coeffs == 15)				? S_DONE	: S_ETA3_2;
			S_ETA3_2	: n_state = (cnt_coeffs == 15)				? S_DONE	: S_ETA3_0;
			S_DONE		: n_state = S_IDLE;
			default		: n_state = S_IDLE;
		endcase
	end

	// Output Logic
	always @(*) begin
		case(n_state)
			S_ETA2		,
			S_ETA3_0	,
			S_ETA3_1	,
			S_ETA3_2	: o_ibytes_ready	= 1;
			default		: o_ibytes_ready	= 0;
		endcase
	end

	always @(*) begin
		case(c_state)
			S_DONE		: o_done	= 1;
			default		: o_done	= 0;
		endcase
	end

// --------------------------------------------------
//	Output Coefficients Counter
// --------------------------------------------------
	reg			[3:0]		cnt_coeffs;
	always @(posedge i_clk or negedge i_rstn) begin
		if (!i_rstn) begin
			cnt_coeffs	<= 0;
		end else begin
			case (c_state)
				S_DONE	: cnt_coeffs <= 0;
				default	: cnt_coeffs <= o_coeffs_valid ? cnt_coeffs + 1 : cnt_coeffs;
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
			assign	ibytes_bwr[64-1-8*i-:8] = {
						i_ibytes[64-1-8*i-7],
						i_ibytes[64-1-8*i-6],
						i_ibytes[64-1-8*i-5],
						i_ibytes[64-1-8*i-4],
						i_ibytes[64-1-8*i-3],
						i_ibytes[64-1-8*i-2],
						i_ibytes[64-1-8*i-1],
						i_ibytes[64-1-8*i-0]
			};
		end
	endgenerate

	// Input Byte Register
	reg			[63:0]		ibytes_reg;
	always @(posedge i_clk) begin
		case (c_state)
			S_ETA2		,
			S_ETA3_0	: ibytes_reg		<= ibytes_bwr       ;
			S_ETA3_1	: ibytes_reg[31:0]	<= ibytes_bwr[31:0] ;
			default		: ibytes_reg		<= i_ibytes			;
		endcase
	end

	always @(posedge i_clk or negedge i_rstn) begin
		if (!i_rstn) begin
			o_coeffs	<= 0;
		end else begin
			case (c_state)
				S_ETA2		: begin
					o_coeffs[48-1-3* 0-:3]	<=	ibytes_bwr[63] + ibytes_bwr[62] - ibytes_bwr[61] - ibytes_bwr[60];
					o_coeffs[48-1-3* 1-:3]	<=	ibytes_bwr[59] + ibytes_bwr[58] - ibytes_bwr[57] - ibytes_bwr[56];
					o_coeffs[48-1-3* 2-:3]	<=	ibytes_bwr[55] + ibytes_bwr[54] - ibytes_bwr[53] - ibytes_bwr[52];
					o_coeffs[48-1-3* 3-:3]	<=	ibytes_bwr[51] + ibytes_bwr[50] - ibytes_bwr[49] - ibytes_bwr[48];
					o_coeffs[48-1-3* 4-:3]	<=	ibytes_bwr[47] + ibytes_bwr[46] - ibytes_bwr[45] - ibytes_bwr[44];
					o_coeffs[48-1-3* 5-:3]	<=	ibytes_bwr[43] + ibytes_bwr[42] - ibytes_bwr[41] - ibytes_bwr[40];
					o_coeffs[48-1-3* 6-:3]	<=	ibytes_bwr[39] + ibytes_bwr[38] - ibytes_bwr[37] - ibytes_bwr[36];
					o_coeffs[48-1-3* 7-:3]	<=	ibytes_bwr[35] + ibytes_bwr[34] - ibytes_bwr[33] - ibytes_bwr[32];
					o_coeffs[48-1-3* 8-:3]	<=	ibytes_bwr[31] + ibytes_bwr[30] - ibytes_bwr[29] - ibytes_bwr[28];
					o_coeffs[48-1-3* 9-:3]	<=	ibytes_bwr[27] + ibytes_bwr[26] - ibytes_bwr[25] - ibytes_bwr[24];
					o_coeffs[48-1-3*10-:3]	<=	ibytes_bwr[23] + ibytes_bwr[22] - ibytes_bwr[21] - ibytes_bwr[20];
					o_coeffs[48-1-3*11-:3]	<=	ibytes_bwr[19] + ibytes_bwr[18] - ibytes_bwr[17] - ibytes_bwr[16];
					o_coeffs[48-1-3*12-:3]	<=	ibytes_bwr[15] + ibytes_bwr[14] - ibytes_bwr[13] - ibytes_bwr[12];
					o_coeffs[48-1-3*13-:3]	<=	ibytes_bwr[11] + ibytes_bwr[10] - ibytes_bwr[ 9] - ibytes_bwr[ 8];
					o_coeffs[48-1-3*14-:3]	<=	ibytes_bwr[ 7] + ibytes_bwr[ 6] - ibytes_bwr[ 5] - ibytes_bwr[ 4];
					o_coeffs[48-1-3*15-:3]	<=	ibytes_bwr[ 3] + ibytes_bwr[ 2] - ibytes_bwr[ 1] - ibytes_bwr[ 0];
				end
				S_ETA3_0	: o_coeffs	<= o_coeffs;
				S_ETA3_1	: begin
					// From IByte Register
					o_coeffs[48-1-3* 0-:3]	<=	ibytes_reg[63] + ibytes_reg[62] + ibytes_reg[61] - ibytes_reg[60] - ibytes_reg[59] - ibytes_reg[58];	// 0
					o_coeffs[48-1-3* 1-:3]	<=	ibytes_reg[57] + ibytes_reg[56] + ibytes_reg[55] - ibytes_reg[54] - ibytes_reg[53] - ibytes_reg[52];	// 1
					o_coeffs[48-1-3* 2-:3]	<=	ibytes_reg[51] + ibytes_reg[50] + ibytes_reg[49] - ibytes_reg[48] - ibytes_reg[47] - ibytes_reg[46];	// 2
					o_coeffs[48-1-3* 3-:3]	<=	ibytes_reg[45] + ibytes_reg[44] + ibytes_reg[43] - ibytes_reg[42] - ibytes_reg[41] - ibytes_reg[40];	// 3
					o_coeffs[48-1-3* 4-:3]	<=	ibytes_reg[39] + ibytes_reg[38] + ibytes_reg[37] - ibytes_reg[36] - ibytes_reg[35] - ibytes_reg[34];	// 4
					o_coeffs[48-1-3* 5-:3]	<=	ibytes_reg[33] + ibytes_reg[32] + ibytes_reg[31] - ibytes_reg[30] - ibytes_reg[29] - ibytes_reg[28];	// 5
					o_coeffs[48-1-3* 6-:3]	<=	ibytes_reg[27] + ibytes_reg[26] + ibytes_reg[25] - ibytes_reg[24] - ibytes_reg[23] - ibytes_reg[22];	// 6
					o_coeffs[48-1-3* 7-:3]	<=	ibytes_reg[21] + ibytes_reg[20] + ibytes_reg[19] - ibytes_reg[18] - ibytes_reg[17] - ibytes_reg[16];	// 7
					o_coeffs[48-1-3* 8-:3]	<=	ibytes_reg[15] + ibytes_reg[14] + ibytes_reg[13] - ibytes_reg[12] - ibytes_reg[11] - ibytes_reg[10];	// 8
					o_coeffs[48-1-3* 9-:3]	<=	ibytes_reg[ 9] + ibytes_reg[ 8] + ibytes_reg[ 7] - ibytes_reg[ 6] - ibytes_reg[ 5] - ibytes_reg[ 4];	// 9
					// From IByte Register & IByte
					o_coeffs[48-1-3*10-:3]	<=	ibytes_reg[ 3] + ibytes_reg[ 2] + ibytes_reg[ 1] - ibytes_reg[ 0] - ibytes_bwr[63] - ibytes_bwr[62];	// 10
					// From IByte
					o_coeffs[48-1-3*11-:3]	<=	ibytes_bwr[61] + ibytes_bwr[60] + ibytes_bwr[59] - ibytes_bwr[58] - ibytes_bwr[57] - ibytes_bwr[56];	// 11
					o_coeffs[48-1-3*12-:3]	<=	ibytes_bwr[55] + ibytes_bwr[54] + ibytes_bwr[53] - ibytes_bwr[52] - ibytes_bwr[51] - ibytes_bwr[50];	// 12
					o_coeffs[48-1-3*13-:3]	<=	ibytes_bwr[49] + ibytes_bwr[48] + ibytes_bwr[47] - ibytes_bwr[46] - ibytes_bwr[45] - ibytes_bwr[44];	// 13
					o_coeffs[48-1-3*14-:3]	<=	ibytes_bwr[43] + ibytes_bwr[42] + ibytes_bwr[41] - ibytes_bwr[40] - ibytes_bwr[39] - ibytes_bwr[38];	// 14
					o_coeffs[48-1-3*15-:3]	<=	ibytes_bwr[37] + ibytes_bwr[36] + ibytes_bwr[35] - ibytes_bwr[34] - ibytes_bwr[33] - ibytes_bwr[32];	// 15
				end
				S_ETA3_2	: begin
					// From IByte
					o_coeffs[48-1-3* 0-:3]	<=	ibytes_reg[31] + ibytes_reg[30] + ibytes_reg[29] - ibytes_reg[28] - ibytes_reg[27] - ibytes_reg[26];	// 0
					o_coeffs[48-1-3* 1-:3]	<=	ibytes_reg[25] + ibytes_reg[24] + ibytes_reg[23] - ibytes_reg[22] - ibytes_reg[21] - ibytes_reg[20];	// 1
					o_coeffs[48-1-3* 2-:3]	<=	ibytes_reg[19] + ibytes_reg[18] + ibytes_reg[17] - ibytes_reg[16] - ibytes_reg[15] - ibytes_reg[14];	// 2
					o_coeffs[48-1-3* 3-:3]	<=	ibytes_reg[13] + ibytes_reg[12] + ibytes_reg[11] - ibytes_reg[10] - ibytes_reg[ 9] - ibytes_reg[ 8];	// 3
					o_coeffs[48-1-3* 4-:3]	<=	ibytes_reg[ 7] + ibytes_reg[ 6] + ibytes_reg[ 5] - ibytes_reg[ 4] - ibytes_reg[ 3] - ibytes_reg[ 2];	// 4
					// From IByte Register & IByte
					o_coeffs[48-1-3* 5-:3]	<=	ibytes_reg[ 1] + ibytes_reg[ 0] + ibytes_bwr[63] - ibytes_bwr[62] - ibytes_bwr[61] - ibytes_bwr[60];	// 5
					// From IByte Register
					o_coeffs[48-1-3* 6-:3]	<=	ibytes_bwr[59] + ibytes_bwr[58] + ibytes_bwr[57] - ibytes_bwr[56] - ibytes_bwr[55] - ibytes_bwr[54];	// 6
					o_coeffs[48-1-3* 7-:3]	<=	ibytes_bwr[53] + ibytes_bwr[52] + ibytes_bwr[51] - ibytes_bwr[50] - ibytes_bwr[49] - ibytes_bwr[48];	// 7
					o_coeffs[48-1-3* 8-:3]	<=	ibytes_bwr[47] + ibytes_bwr[46] + ibytes_bwr[45] - ibytes_bwr[44] - ibytes_bwr[43] - ibytes_bwr[42];	// 8
					o_coeffs[48-1-3* 9-:3]	<=	ibytes_bwr[41] + ibytes_bwr[40] + ibytes_bwr[39] - ibytes_bwr[38] - ibytes_bwr[37] - ibytes_bwr[36];	// 9
					o_coeffs[48-1-3*10-:3]	<=	ibytes_bwr[35] + ibytes_bwr[34] + ibytes_bwr[33] - ibytes_bwr[32] - ibytes_bwr[31] - ibytes_bwr[30];	// 10
					o_coeffs[48-1-3*11-:3]	<=	ibytes_bwr[29] + ibytes_bwr[28] + ibytes_bwr[27] - ibytes_bwr[26] - ibytes_bwr[25] - ibytes_bwr[24];	// 11
					o_coeffs[48-1-3*12-:3]	<=	ibytes_bwr[23] + ibytes_bwr[22] + ibytes_bwr[21] - ibytes_bwr[20] - ibytes_bwr[19] - ibytes_bwr[18];	// 12
					o_coeffs[48-1-3*13-:3]	<=	ibytes_bwr[17] + ibytes_bwr[16] + ibytes_bwr[15] - ibytes_bwr[14] - ibytes_bwr[13] - ibytes_bwr[12];	// 13
					o_coeffs[48-1-3*14-:3]	<=	ibytes_bwr[11] + ibytes_bwr[10] + ibytes_bwr[ 9] - ibytes_bwr[ 8] - ibytes_bwr[ 7] - ibytes_bwr[ 6];	// 14
					o_coeffs[48-1-3*15-:3]	<=	ibytes_bwr[ 5] + ibytes_bwr[ 4] + ibytes_bwr[ 3] - ibytes_bwr[ 2] - ibytes_bwr[ 1] - ibytes_bwr[ 0];	// 15
				end
			endcase
		end
	end

	always @(posedge i_clk or negedge i_rstn) begin
		if (!i_rstn) begin
			o_coeffs_valid	<= 0;
		end else begin
			case (c_state)
				S_ETA2		,
				S_ETA3_1	,
				S_ETA3_2	: o_coeffs_valid	<= n_state != S_DONE ? 1 : 0;
				default		: o_coeffs_valid	<= 0;
			endcase
		end
	end

	`ifdef DEBUG
	reg			[127:0]			ASCII_C_STATE;
	always @(*) begin
		case (c_state)
			S_IDLE		: ASCII_C_STATE = "IDLE  ";
			S_ETA2		: ASCII_C_STATE = "ETA2  ";
			S_ETA3_0	: ASCII_C_STATE = "ETA3_0";
			S_ETA3_1	: ASCII_C_STATE = "ETA3_1";
			S_ETA3_2	: ASCII_C_STATE = "ETA3_2";
			S_DONE		: ASCII_C_STATE = "DONE  ";
		endcase
	end

	reg			[256*3-1:0]	COEFFS;
	always @(posedge i_clk or negedge i_rstn) begin
		if (!i_rstn) begin
			COEFFS	<= 0;
		end else begin
			if (o_coeffs_valid) begin
				COEFFS[256*3-1-16*3*cnt_coeffs-:48]	<= o_coeffs;
			end else begin
				COEFFS	<= COEFFS;
			end
		end
	end
	`endif

endmodule
