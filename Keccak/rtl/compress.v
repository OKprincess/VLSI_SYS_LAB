// ==================================================
//	[ VLSISYS Lab. ]
//	* Author		: Woong Choi (woongchoi@sm.ac.kr)
//	* Filename		: compress.v
//	* Description	: 
// ==================================================

(* use_dsp = "no" *)
module compress
(	
	output reg	[10:0]		o_coeff,
	input		[12:0]		i_coeff,
	input		[ 3:0]		i_d
);

	reg			[23:0]		float;
	always @(*) begin
		case (i_d)
			4'd 1	: float	= 24'h00275f;
			4'd 4	: float	= 24'h013afb;
			4'd 5	: float	= 24'h0275f7;
			4'd10	: float	= 24'h4ebede;
			4'd11	: float	= 24'h9d7dbb;
			default	: float	= 24'h000000;
		endcase
	end

	wire		[36:0]		mult;
	wire		[12:0]		mult_roundup;
	assign		mult			= float * i_coeff;
	assign		mult_roundup	= mult[36:24] +  mult[23];

	always @(*) begin
		case (i_d)
			4'd 1	: o_coeff	= mult_roundup[ 0:0];
			4'd 4	: o_coeff	= mult_roundup[ 3:0];
			4'd 5	: o_coeff	= mult_roundup[ 4:0];
			4'd10	: o_coeff	= mult_roundup[ 9:0];
			4'd11	: o_coeff	= mult_roundup[10:0];
			default	: o_coeff	= 0;
		endcase
	end

endmodule
