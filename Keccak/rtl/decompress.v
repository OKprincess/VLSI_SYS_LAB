// ==================================================
//	[ VLSISYS Lab. ]
//	* Author		: Woong Choi (woongchoi@sm.ac.kr)
//	* Filename		: decompress.v
//	* Description	: 
// ==================================================

module decompress
(	
	output 		[11:0]		o_coeff,
	input		[10:0]		i_coeff,
	input		[ 3:0]		i_d
);

	reg			[13:0]		float;
	always @(*) begin
		case (i_d)
			4'd 1	: float	= 14'h3404;
			4'd 4	: float	= 14'h0681;
			4'd 5	: float	= 14'h0340;
			4'd10	: float	= 14'h001a;
			4'd11	: float	= 14'h000d;
			default	: float	= 14'h0;
		endcase
	end

	wire		[24:0]		mult;
	assign		mult		= float * i_coeff;
	assign		o_coeff		= mult[14:3] +  mult[2];

endmodule
