// ==================================================
//	[ VLSISYS Lab. ]
//	* Author		: Woong Choi (woongchoi@sm.ac.kr)
//	* Filename		: keygen.v
//	* Date			: 2025-03-01 16:04:30
//	* Description	: 
// ==================================================

module keygen
#(	
	parameter	BW_DATA			= 32,
	parameter	BW_ADDR			= 4,
	parameter	BW_CTRL			= 4
)
(	
	output reg	[BW_DATA-1:0]	o_data,
	output reg					o_valid,
	input		[BW_DATA-1:0]	i_data,
	input		[BW_ADDR-1:0]	i_addr,
	input		[BW_CTRL-1:0]	i_ctrl,
	input						i_clk,
	input						i_rstn
);



endmodule

