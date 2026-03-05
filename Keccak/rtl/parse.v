// ==================================================
//	[ VLSISYS Lab. ]
//	* Author		: Woong Choi (woongchoi@sm.ac.kr)
//	* Filename		: parse.v
//	* Description	: 
// ==================================================

`include	"configs.v"

module parse
(	
	output reg	[4*12-1:0]	o_coeffs,
	output reg				o_coeffs_valid,
	output reg				o_ibytes_ready,
	output reg				o_done,
	input		[    63:0]	i_ibytes,
	input					i_ibytes_valid,
	input					i_clk,
	input					i_rstn
);

// --------------------------------------------------
//	FSM (Control)
// --------------------------------------------------
	localparam	S_IDLE		= 3'd0  ;
	localparam	S_PRS0		= 3'd1  ;
	localparam	S_PRS1		= 3'd2  ;
	localparam	S_PRS2		= 3'd3  ;
	localparam	S_PRS3		= 3'd4  ;
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
			S_IDLE	: n_state = (i_ibytes_valid  ) ? S_PRS0 : S_IDLE;
			S_PRS0	: n_state = (cnt_coeffs == 63) ? S_DONE : S_PRS1;
			S_PRS1	: n_state = (cnt_coeffs == 63) ? S_DONE : S_PRS2;
			S_PRS2	: n_state = (cnt_coeffs == 63) ? S_DONE : S_PRS3;
			S_PRS3	: n_state = (cnt_coeffs == 63) ? S_DONE : S_PRS0;
			S_DONE	: n_state = S_IDLE;
		endcase
	end

	// Output Logic
	always @(*) begin
		case(c_state)
			S_DONE	: o_done			= 1;
			default	: o_done			= 0;
		endcase
	end

	always @(*) begin
		case(n_state)
			S_PRS0	,
			S_PRS1	,
			S_PRS2	: o_ibytes_ready	= 1;
			default	: o_ibytes_ready	= 0;
		endcase
	end

// --------------------------------------------------
//	Input Byte Register
// --------------------------------------------------
	reg			[63:0]		ibytes_reg;
	always @(posedge i_clk) begin
		ibytes_reg	<= i_ibytes;
	end

// --------------------------------------------------
//	D1, D2 Computation
// --------------------------------------------------
	reg			[11:0]		d1_0;
	reg			[11:0]		d2_0;
	reg			[11:0]		d1_1;
	reg			[11:0]		d2_1;
	reg						d1_if_0;
	reg						d2_if_0;
	reg						d1_if_1;
	reg						d2_if_1;

	always @(*) begin
		case (c_state)
			S_PRS0	: begin
				d1_0 = (i_ibytes  [64-1-8*0-:8]		) + 256*(i_ibytes  [64-1-8*1-:8] % 16);
				d2_0 = (i_ibytes  [64-1-8*1-:8] >> 4) +  16*(i_ibytes  [64-1-8*2-:8]     );
				d1_1 = (i_ibytes  [64-1-8*3-:8]		) + 256*(i_ibytes  [64-1-8*4-:8] % 16);
				d2_1 = (i_ibytes  [64-1-8*4-:8] >> 4) +  16*(i_ibytes  [64-1-8*5-:8]     );
			end
			S_PRS1	: begin
				d1_0 = (ibytes_reg[64-1-8*6-:8]		) + 256*(ibytes_reg[64-1-8*7-:8] % 16);
				d2_0 = (ibytes_reg[64-1-8*7-:8] >> 4) +  16*(i_ibytes  [64-1-8*0-:8]     );
				d1_1 = (i_ibytes  [64-1-8*1-:8]		) + 256*(i_ibytes  [64-1-8*2-:8] % 16);
				d2_1 = (i_ibytes  [64-1-8*2-:8] >> 4) +  16*(i_ibytes  [64-1-8*3-:8]     );
			end
			S_PRS2	: begin
				d1_0 = (ibytes_reg[64-1-8*4-:8]		) + 256*(ibytes_reg[64-1-8*5-:8] % 16);
				d2_0 = (ibytes_reg[64-1-8*5-:8] >> 4) +  16*(ibytes_reg[64-1-8*6-:8]     );
				d1_1 = (ibytes_reg[64-1-8*7-:8]		) + 256*(i_ibytes  [64-1-8*0-:8] % 16);
				d2_1 = (i_ibytes  [64-1-8*0-:8] >> 4) +  16*(i_ibytes  [64-1-8*1-:8]     );
			end
			S_PRS3	: begin
				d1_0 = (ibytes_reg[64-1-8*2-:8]		) + 256*(ibytes_reg[64-1-8*3-:8] % 16);
				d2_0 = (ibytes_reg[64-1-8*3-:8] >> 4) +  16*(ibytes_reg[64-1-8*4-:8]     );
				d1_1 = (ibytes_reg[64-1-8*5-:8]		) + 256*(ibytes_reg[64-1-8*6-:8] % 16);
				d2_1 = (ibytes_reg[64-1-8*6-:8] >> 4) +  16*(ibytes_reg[64-1-8*7-:8]     );
			end
			default	: begin
				d1_0 = 0;
				d2_0 = 0;
				d1_1 = 0;
				d2_1 = 0;
			end
		endcase
	end

	always @(*) begin
		case(c_state)
			S_PRS0	,
			S_PRS1	,
			S_PRS2	,
			S_PRS3	: begin
				d1_if_0 = (d1_0 < `KYBER_CONFIG_Q)																	? 1:0;
				d2_if_0 = (d2_0 < `KYBER_CONFIG_Q) && ((cnt_loop + d1_if_0)	< `KYBER_CONFIG_N)						? 1:0;
				d1_if_1 = (d1_1 < `KYBER_CONFIG_Q)																	? 1:0;
				d2_if_1 = (d2_1 < `KYBER_CONFIG_Q) && ((cnt_loop + d1_if_0 + d2_if_0 + d1_if_1) < `KYBER_CONFIG_N)	? 1:0;
			end
			default	: begin
				d1_if_0 = 0;
				d2_if_0 = 0;
				d1_if_1 = 0;
				d2_if_1 = 0;
			end
		endcase
	end

	//	Counter for While Loop
	wire		[2:0]		add_if;
	reg			[7:0]		cnt_loop;	// 0 ~ 255

	assign	add_if = ((c_state == S_IDLE) || (c_state == S_DONE))	? 0 : d1_if_0 + d2_if_0 + d1_if_1 + d2_if_1;

	always @(posedge i_clk or negedge i_rstn) begin
		if(!i_rstn) begin
			cnt_loop	<= 0;
		end else begin
			case (c_state)
				S_PRS0	,
				S_PRS1	,
				S_PRS2	,
				S_PRS3	: begin
					case (add_if)
						3'd0	: cnt_loop	<= (cnt_loop + 0) <= 255 ? cnt_loop + 0 : cnt_loop;
						3'd1	: cnt_loop	<= (cnt_loop + 1) <= 255 ? cnt_loop + 1 : cnt_loop;
						3'd2	: cnt_loop	<= (cnt_loop + 2) <= 255 ? cnt_loop + 2 : cnt_loop;
						3'd3	: cnt_loop	<= (cnt_loop + 3) <= 255 ? cnt_loop + 3 : cnt_loop;
						3'd4	: cnt_loop	<= (cnt_loop + 4) <= 255 ? cnt_loop + 4 : cnt_loop;
						default	: cnt_loop	<= cnt_loop;
					endcase
				end
				default	: cnt_loop	<= 0;
			endcase
		end
	end

// --------------------------------------------------
//	FSM (Output Coefficients)
// --------------------------------------------------
	localparam	CFF_EMPTY		= 2'd0  ;
	localparam	CFF_FILL1		= 2'd1  ;
	localparam	CFF_FILL2		= 2'd2  ;
	localparam	CFF_FILL3		= 2'd3  ;

	reg			[1:0]		c_state_cff;
	reg			[1:0]		n_state_cff;

	// State Register
	always @(posedge i_clk or negedge i_rstn) begin
		if(!i_rstn) begin
			c_state_cff	<= CFF_EMPTY;
		end else begin
			case (c_state)
				S_DONE	: c_state_cff	<= CFF_EMPTY;
				default	: c_state_cff	<= n_state_cff;
			endcase
		end
	end

	// Next State Logic
	always @(*) begin
		case({c_state_cff, add_if})
			{CFF_EMPTY, 3'd0}	: n_state_cff	= CFF_EMPTY;
			{CFF_EMPTY, 3'd1}	: n_state_cff	= CFF_FILL1;
			{CFF_EMPTY, 3'd2}	: n_state_cff	= CFF_FILL2;
			{CFF_EMPTY, 3'd3}	: n_state_cff	= CFF_FILL3;
			{CFF_EMPTY, 3'd4}	: n_state_cff	= CFF_EMPTY;

			{CFF_FILL1, 3'd0}	: n_state_cff	= CFF_FILL1;
			{CFF_FILL1, 3'd1}	: n_state_cff	= CFF_FILL2;
			{CFF_FILL1, 3'd2}	: n_state_cff	= CFF_FILL3;
			{CFF_FILL1, 3'd3}	: n_state_cff	= CFF_EMPTY;
			{CFF_FILL1, 3'd4}	: n_state_cff	= CFF_FILL1;

			{CFF_FILL2, 3'd0}	: n_state_cff	= CFF_FILL2;
			{CFF_FILL2, 3'd1}	: n_state_cff	= CFF_FILL3;
			{CFF_FILL2, 3'd2}	: n_state_cff	= CFF_EMPTY;
			{CFF_FILL2, 3'd3}	: n_state_cff	= CFF_FILL1;
			{CFF_FILL2, 3'd4}	: n_state_cff	= CFF_FILL2;

			{CFF_FILL3, 3'd0}	: n_state_cff	= CFF_FILL3;
			{CFF_FILL3, 3'd1}	: n_state_cff	= CFF_EMPTY;
			{CFF_FILL3, 3'd2}	: n_state_cff	= CFF_FILL1;
			{CFF_FILL3, 3'd3}	: n_state_cff	= CFF_FILL2;
			{CFF_FILL3, 3'd4}	: n_state_cff	= CFF_FILL3;
		endcase
	end

// --------------------------------------------------
//	Coefficients Register
// --------------------------------------------------
	reg		[3*12-1:0]		coeffs_reg;

	always @(posedge i_clk or negedge i_rstn) begin
		if (!i_rstn) begin
			coeffs_reg	<= 0;
		end else begin
			case ({c_state_cff, d1_if_0, d2_if_0, d1_if_1, d2_if_1})
				//	Empty && 1 Coeffs
				{CFF_EMPTY, 4'b0001}: coeffs_reg[3*12-1-12*0-:12*1] <= {                  d2_1} ;
				{CFF_EMPTY, 4'b0010}: coeffs_reg[3*12-1-12*0-:12*1] <= {            d1_1      } ;
				{CFF_EMPTY, 4'b0100}: coeffs_reg[3*12-1-12*0-:12*1] <= {      d2_0            } ;
				{CFF_EMPTY, 4'b1000}: coeffs_reg[3*12-1-12*0-:12*1] <= {d1_0                  } ;
				//	Empty && 2 Coeffs
				{CFF_EMPTY, 4'b0011}: coeffs_reg[3*12-1-12*0-:12*2] <= {            d1_1, d2_1} ;
				{CFF_EMPTY, 4'b0101}: coeffs_reg[3*12-1-12*0-:12*2] <= {      d2_0,       d2_1} ;
				{CFF_EMPTY, 4'b0110}: coeffs_reg[3*12-1-12*0-:12*2] <= {      d2_0, d1_1      } ;
				{CFF_EMPTY, 4'b1001}: coeffs_reg[3*12-1-12*0-:12*2] <= {d1_0,             d2_1} ;
				{CFF_EMPTY, 4'b1010}: coeffs_reg[3*12-1-12*0-:12*2] <= {d1_0,       d1_1      } ;
				{CFF_EMPTY, 4'b1100}: coeffs_reg[3*12-1-12*0-:12*2] <= {d1_0, d2_0            } ;
				//	Empty && 3 Coeffs
				{CFF_EMPTY, 4'b0111}: coeffs_reg[3*12-1-12*0-:12*3] <= {      d2_0, d1_1, d2_1} ;
				{CFF_EMPTY, 4'b1011}: coeffs_reg[3*12-1-12*0-:12*3] <= {d1_0,       d1_1, d2_1} ;
				{CFF_EMPTY, 4'b1101}: coeffs_reg[3*12-1-12*0-:12*3] <= {d1_0, d2_0,       d2_1} ;
				{CFF_EMPTY, 4'b1110}: coeffs_reg[3*12-1-12*0-:12*3] <= {d1_0, d2_0, d1_1      } ;
				//	Empty && 4 Coeffs
				{CFF_EMPTY, 4'b1111}: coeffs_reg                    <= coeffs_reg               ;
				//	Fill1 && 1 Coeffs
				{CFF_FILL1, 4'b0001}: coeffs_reg[3*12-1-12*1-:12*1] <= {                  d2_1} ;
				{CFF_FILL1, 4'b0010}: coeffs_reg[3*12-1-12*1-:12*1] <= {            d1_1      } ;
				{CFF_FILL1, 4'b0100}: coeffs_reg[3*12-1-12*1-:12*1] <= {      d2_0            } ;
				{CFF_FILL1, 4'b1000}: coeffs_reg[3*12-1-12*1-:12*1] <= {d1_0                  } ;
				//	Fill1 && 2 Coeffs
				{CFF_FILL1, 4'b0011}: coeffs_reg[3*12-1-12*1-:12*2] <= {            d1_1, d2_1} ;
				{CFF_FILL1, 4'b0101}: coeffs_reg[3*12-1-12*1-:12*2] <= {      d2_0,       d2_1} ;
				{CFF_FILL1, 4'b0110}: coeffs_reg[3*12-1-12*1-:12*2] <= {      d2_0, d1_1      } ;
				{CFF_FILL1, 4'b1001}: coeffs_reg[3*12-1-12*1-:12*2] <= {d1_0,             d2_1} ;
				{CFF_FILL1, 4'b1010}: coeffs_reg[3*12-1-12*1-:12*2] <= {d1_0,       d1_1      } ;
				{CFF_FILL1, 4'b1100}: coeffs_reg[3*12-1-12*1-:12*2] <= {d1_0, d2_0            } ;
				//	Fill1 && 4 Coeffs
				{CFF_FILL1, 4'b1111}: coeffs_reg[3*12-1-12*0-:12*1] <= {                  d2_1} ;
				//	Fill2 && 1 Coeffs
				{CFF_FILL2, 4'b0001}: coeffs_reg[3*12-1-12*2-:12*1] <= {                  d2_1} ;
				{CFF_FILL2, 4'b0010}: coeffs_reg[3*12-1-12*2-:12*1] <= {            d1_1      } ;
				{CFF_FILL2, 4'b0100}: coeffs_reg[3*12-1-12*2-:12*1] <= {      d2_0            } ;
				{CFF_FILL2, 4'b1000}: coeffs_reg[3*12-1-12*2-:12*1] <= {d1_0                  } ;
				//	Fill2 && 3 Coeffs
				{CFF_FILL2, 4'b0111}: coeffs_reg[3*12-1-12*0-:12*1] <= {                  d2_1} ;
				{CFF_FILL2, 4'b1011}: coeffs_reg[3*12-1-12*0-:12*1] <= {                  d2_1} ;
				{CFF_FILL2, 4'b1101}: coeffs_reg[3*12-1-12*0-:12*1] <= {                  d2_1} ;
				{CFF_FILL2, 4'b1110}: coeffs_reg[3*12-1-12*0-:12*1] <= {            d1_1      } ;
				//	Fill2 && 4 Coeffs
				{CFF_FILL2, 4'b1111}: coeffs_reg[3*12-1-12*0-:12*2] <= {            d1_1, d2_1} ;
				//	Fill3 && 2 Coeffs
				{CFF_FILL3, 4'b0011}: coeffs_reg[3*12-1-12*0-:12*1] <= {                  d2_1} ;
				{CFF_FILL3, 4'b0101}: coeffs_reg[3*12-1-12*0-:12*1] <= {                  d2_1} ;
				{CFF_FILL3, 4'b0110}: coeffs_reg[3*12-1-12*0-:12*1] <= {            d1_1      } ;
				{CFF_FILL3, 4'b1001}: coeffs_reg[3*12-1-12*0-:12*1] <= {                  d2_1} ;
				{CFF_FILL3, 4'b1010}: coeffs_reg[3*12-1-12*0-:12*1] <= {            d1_1      } ;
				{CFF_FILL3, 4'b1100}: coeffs_reg[3*12-1-12*0-:12*1] <= {      d2_0            } ;
				//	Fill3 && 3 Coeffs
				{CFF_FILL3, 4'b0111}: coeffs_reg[3*12-1-12*0-:12*2] <= {            d1_1, d2_1} ;
				{CFF_FILL3, 4'b1011}: coeffs_reg[3*12-1-12*0-:12*2] <= {            d1_1, d2_1} ;
				{CFF_FILL3, 4'b1101}: coeffs_reg[3*12-1-12*0-:12*2] <= {      d2_0,       d2_1} ;
				{CFF_FILL3, 4'b1110}: coeffs_reg[3*12-1-12*0-:12*2] <= {      d2_0, d1_1      } ;
				//	Fill3 && 4 Coeffs
				{CFF_FILL3, 4'b1111}: coeffs_reg[3*12-1-12*0-:12*3] <= {      d2_0, d1_1, d2_1} ;
				default				: coeffs_reg                    <= coeffs_reg;
			endcase
		end
	end

	always @(posedge i_clk or negedge i_rstn) begin
		if (!i_rstn) begin
			o_coeffs		<= 0;
			o_coeffs_valid	<= 0; 
		end else begin
			case ({c_state_cff, d1_if_0, d2_if_0, d1_if_1, d2_if_1})
				//	Empty && 4 Coeffs
				{CFF_EMPTY, 4'b1111}: begin	o_coeffs	<= {                    d1_0, d2_0, d1_1, d2_1} ;	o_coeffs_valid	<= 1;	end
				//	Fill1 && 3 Coeffs
				{CFF_FILL1, 4'b0111}: begin	o_coeffs	<= {coeffs_reg[3*12-1-:12*1], d2_0, d1_1, d2_1} ;	o_coeffs_valid	<= 1;	end
				{CFF_FILL1, 4'b1011}: begin	o_coeffs	<= {coeffs_reg[3*12-1-:12*1], d1_0, d1_1, d2_1} ;	o_coeffs_valid	<= 1;	end
				{CFF_FILL1, 4'b1101}: begin	o_coeffs	<= {coeffs_reg[3*12-1-:12*1], d1_0, d2_0, d2_1} ;	o_coeffs_valid	<= 1;	end
				{CFF_FILL1, 4'b1110}: begin	o_coeffs	<= {coeffs_reg[3*12-1-:12*1], d1_0, d2_0, d1_1} ;	o_coeffs_valid	<= 1;	end
				//	Fill1 && 4 Coeffs
				{CFF_FILL1, 4'b1111}: begin	o_coeffs	<= {coeffs_reg[3*12-1-:12*1], d1_0, d2_0, d1_1} ;	o_coeffs_valid	<= 1;	end
				//	Fill2 && 2 Coeffs
				{CFF_FILL2, 4'b0011}: begin	o_coeffs	<= {coeffs_reg[3*12-1-:12*2], d1_1, d2_1}       ;	o_coeffs_valid	<= 1;	end
				{CFF_FILL2, 4'b0101}: begin	o_coeffs	<= {coeffs_reg[3*12-1-:12*2], d2_0, d2_1}       ;	o_coeffs_valid	<= 1;	end
				{CFF_FILL2, 4'b0110}: begin	o_coeffs	<= {coeffs_reg[3*12-1-:12*2], d2_0, d1_1}       ;	o_coeffs_valid	<= 1;	end
				{CFF_FILL2, 4'b1001}: begin	o_coeffs	<= {coeffs_reg[3*12-1-:12*2], d1_0, d2_1}       ;	o_coeffs_valid	<= 1;	end
				{CFF_FILL2, 4'b1010}: begin	o_coeffs	<= {coeffs_reg[3*12-1-:12*2], d1_0, d1_1}       ;	o_coeffs_valid	<= 1;	end
				{CFF_FILL2, 4'b1100}: begin	o_coeffs	<= {coeffs_reg[3*12-1-:12*2], d1_0, d2_0}       ;	o_coeffs_valid	<= 1;	end
				//	Fill2 && 3 Coeffs
				{CFF_FILL2, 4'b0111}: begin	o_coeffs	<= {coeffs_reg[3*12-1-:12*2], d2_0, d1_1}       ;	o_coeffs_valid	<= 1;	end
				{CFF_FILL2, 4'b1011}: begin	o_coeffs	<= {coeffs_reg[3*12-1-:12*2], d1_0, d1_1}       ;	o_coeffs_valid	<= 1;	end
				{CFF_FILL2, 4'b1101}: begin	o_coeffs	<= {coeffs_reg[3*12-1-:12*2], d1_0, d2_0}       ;	o_coeffs_valid	<= 1;	end
				{CFF_FILL2, 4'b1110}: begin	o_coeffs	<= {coeffs_reg[3*12-1-:12*2], d1_0, d2_0}       ;	o_coeffs_valid	<= 1;	end
				//	Fill2 && 4 Coeffs
				{CFF_FILL2, 4'b1111}: begin	o_coeffs	<= {coeffs_reg[3*12-1-:12*2], d1_0, d2_0}       ;	o_coeffs_valid	<= 1;	end
				//	Fill3 && 1 Coeffs
				{CFF_FILL3, 4'b0001}: begin	o_coeffs	<= {coeffs_reg[3*12-1-:12*3], d2_1}             ;	o_coeffs_valid	<= 1;	end
				{CFF_FILL3, 4'b0010}: begin	o_coeffs	<= {coeffs_reg[3*12-1-:12*3], d1_1}             ;	o_coeffs_valid	<= 1;	end
				{CFF_FILL3, 4'b0100}: begin	o_coeffs	<= {coeffs_reg[3*12-1-:12*3], d2_0}             ;	o_coeffs_valid	<= 1;	end
				{CFF_FILL3, 4'b1000}: begin	o_coeffs	<= {coeffs_reg[3*12-1-:12*3], d1_0}             ;	o_coeffs_valid	<= 1;	end
				//	Fill3 && 2 Coeffs
				{CFF_FILL3, 4'b0011}: begin	o_coeffs	<= {coeffs_reg[3*12-1-:12*3], d1_1}             ;	o_coeffs_valid	<= 1;	end
				{CFF_FILL3, 4'b0101}: begin	o_coeffs	<= {coeffs_reg[3*12-1-:12*3], d2_0}             ;	o_coeffs_valid	<= 1;	end
				{CFF_FILL3, 4'b0110}: begin	o_coeffs	<= {coeffs_reg[3*12-1-:12*3], d2_0}             ;	o_coeffs_valid	<= 1;	end
				{CFF_FILL3, 4'b1001}: begin	o_coeffs	<= {coeffs_reg[3*12-1-:12*3], d1_0}             ;	o_coeffs_valid	<= 1;	end
				{CFF_FILL3, 4'b1010}: begin	o_coeffs	<= {coeffs_reg[3*12-1-:12*3], d1_0}             ;	o_coeffs_valid	<= 1;	end
				{CFF_FILL3, 4'b1100}: begin	o_coeffs	<= {coeffs_reg[3*12-1-:12*3], d1_0}             ;	o_coeffs_valid	<= 1;	end
				//	Fill3 && 3 Coeffs
				{CFF_FILL3, 4'b0111}: begin	o_coeffs	<= {coeffs_reg[3*12-1-:12*3], d2_0}             ;	o_coeffs_valid	<= 1;	end
				{CFF_FILL3, 4'b1011}: begin	o_coeffs	<= {coeffs_reg[3*12-1-:12*3], d1_0}             ;	o_coeffs_valid	<= 1;	end
				{CFF_FILL3, 4'b1101}: begin	o_coeffs	<= {coeffs_reg[3*12-1-:12*3], d1_0}             ;	o_coeffs_valid	<= 1;	end
				{CFF_FILL3, 4'b1110}: begin	o_coeffs	<= {coeffs_reg[3*12-1-:12*3], d1_0}             ;	o_coeffs_valid	<= 1;	end
				//	Fill3 && 4 Coeffs
				{CFF_FILL3, 4'b1111}: begin	o_coeffs	<= {coeffs_reg[3*12-1-:12*3], d1_0}             ;	o_coeffs_valid	<= 1;	end
				default				: begin	o_coeffs	<= o_coeffs                                     ;	o_coeffs_valid	<= 0;	end
			endcase
		end
	end

	reg		[6:0]			cnt_coeffs;
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

	`ifdef DEBUG
	reg			[127:0]			ASCII_C_STATE;
	always @(*) begin
		case (c_state)
			S_IDLE	: ASCII_C_STATE = "IDLE";
			S_PRS0	: ASCII_C_STATE = "PRS0";
			S_PRS1	: ASCII_C_STATE = "PRS1";
			S_PRS2	: ASCII_C_STATE = "PRS2";
			S_PRS3	: ASCII_C_STATE = "PRS3";
			S_DONE	: ASCII_C_STATE = "DONE";
		endcase
	end

	reg			[127:0]			ASCII_C_STATE_CFF;
	always @(*) begin
		case (c_state_cff)
			CFF_EMPTY	: ASCII_C_STATE_CFF = "EMPTY";
			CFF_FILL1	: ASCII_C_STATE_CFF = "FILL1";
			CFF_FILL2	: ASCII_C_STATE_CFF = "FILL2";
			CFF_FILL3	: ASCII_C_STATE_CFF = "FILL3";
		endcase
	end

	reg			[256*12-1:0]	COEFFS;
	always @(posedge i_clk or negedge i_rstn) begin
		if (!i_rstn) begin
			COEFFS	<= 0;
		end else begin
			if (o_coeffs_valid) begin
				COEFFS[256*12-1-4*12*cnt_coeffs-:48]	<= o_coeffs;
			end else begin
				COEFFS	<= COEFFS;
			end
		end
	end

	`endif

endmodule
