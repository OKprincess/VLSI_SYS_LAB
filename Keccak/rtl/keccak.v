// ==================================================
//	[ VLSISYS Lab. ]
//	* Author		: Woong Choi (woongchoi@sm.ac.kr)
//	* Filename		: keccak.v
//	* Description	: 
// ==================================================

`include	"keccakf1600.v"

module keccak
(	
	output reg	[64-1:0]	o_obytes,
	output reg				o_obytes_done,
	output reg				o_obytes_valid,
	output reg				o_ibytes_ready,
	input		[   1:0]	i_mode,
	input		[64-1:0]	i_ibytes,
	input					i_ibytes_valid,
	input		[11-1:0]	i_ibytes_len,
	input		[10-1:0]	i_obytes_len,
	input					i_clk,
	input					i_rstn
);

// --------------------------------------------------
//	Parameters
// --------------------------------------------------
	localparam				SHAKE128	= 2'b00;
	localparam				SHAKE256	= 2'b01;
	localparam				SHA3_256	= 2'b10;
	localparam				SHA3_512	= 2'b11;

	reg			[7:0]		rate            ; // Bytes
	reg			[7:0]		suffix          ;
	reg			[7:0]		cnt_ibytes      ;
	reg			[6:0]		cnt_obytes      ;
	reg			[7:0]		cnt_block       ;
	reg			[9:0]		obytes_len_init ;

	// Rate (Bytes)
	always @(*) begin
		case (i_mode)
			SHAKE128:	rate	= 168;
			SHAKE256,
			SHA3_256:	rate	= 136;
			SHA3_512:	rate	=  72;
		endcase
	end

	// Delimted Suffix
	always @(*) begin
		case (i_mode)
			SHAKE128,
			SHAKE256:	suffix	= 8'h1F;
			SHA3_256,
			SHA3_512:	suffix	= 8'h06;
		endcase
	end

	// Output Byte Length
	always @(*) begin
		case (i_mode)
			SHAKE128,
			SHAKE256:	obytes_len_init	= i_obytes_len ; // outputByteLen
			SHA3_256:	obytes_len_init	= 32           ; // 32 bytes
			SHA3_512:	obytes_len_init	= 64           ; // 64 bytes
		endcase
	end

// --------------------------------------------------
//	FSM
// --------------------------------------------------
	localparam	S_IDLE			= 3'd0;
	localparam	S_ABSB			= 3'd1;
	localparam	S_ABSB_KECCAK	= 3'd2;
	localparam	S_PADD_KECCAK	= 3'd3;
	localparam	S_SQUZ			= 3'd4;
	localparam	S_SQUZ_KECCAK	= 3'd5;
	localparam	S_DONE			= 3'd6;

	reg			[ 2:0]		p_state        ;
	reg			[ 2:0]		c_state        ;
	reg			[ 2:0]		n_state        ;
	reg			[ 7:0]		block_size     ;
	wire		[ 7:0]		block_size_mod ;
	reg			[10:0]		input_offset   ;
	reg			[ 9:0]		obytes_len     ;

	reg						block_last;
	always @(*) begin
		case (c_state)
			S_ABSB	,
			S_SQUZ	: block_last	= (cnt_block + 1) == block_size_mod/8 ? 1:0;
			default	: block_last	= 0;
		endcase
	end

	// State Register
	always @(posedge i_clk or negedge i_rstn) begin
		if(!i_rstn) begin
			p_state	<= S_IDLE;
			c_state	<= S_IDLE;
		end else begin
			p_state	<= c_state;
			c_state	<= n_state;
		end
	end

	// Next State Logic
	always @(*) begin
		case(c_state)
			S_IDLE			: n_state	=	i_ibytes_valid								? S_ABSB		: S_IDLE;
			S_ABSB			: n_state	=	!block_last 								? S_ABSB		:
											block_size == rate							? S_ABSB_KECCAK : 
											input_offset + block_size < i_ibytes_len	? S_ABSB		: S_PADD_KECCAK;
			S_ABSB_KECCAK	: n_state	=	!keccak_ostate_valid						? S_ABSB_KECCAK	:
											input_offset < i_ibytes_len					? S_ABSB		: S_PADD_KECCAK;
			S_PADD_KECCAK	: n_state	=	!keccak_ostate_valid						? S_PADD_KECCAK	: S_SQUZ;
			S_SQUZ			: n_state	=	!block_last									? S_SQUZ		:
											obytes_len - block_size > 0					? S_SQUZ_KECCAK : S_DONE;
			S_SQUZ_KECCAK	: n_state	=	!keccak_ostate_valid						? S_SQUZ_KECCAK	: S_SQUZ;
			S_DONE			: n_state	=	S_IDLE;
		endcase
	end

	always @(posedge i_clk or negedge i_rstn) begin
		if (!i_rstn) begin
			cnt_block	<= 0;
		end else begin
			case (c_state)
				S_ABSB	: cnt_block <= p_state == S_ABSB ? cnt_block + 1 : cnt_block;
				S_SQUZ	: cnt_block <= cnt_block + 1;
				default	: cnt_block <= 0;
			endcase
		end
	end

	always @(posedge i_clk or negedge i_rstn) begin
		if (!i_rstn) begin
			obytes_len	<= 0;
		end else begin
			case (c_state)
				S_ABSB	: obytes_len <= obytes_len_init;
				S_SQUZ	: obytes_len <= block_last ? obytes_len - block_size : obytes_len;
				default	: obytes_len <= obytes_len;
			endcase
		end
	end

	always @(*) begin
		case (c_state)
			S_ABSB			: block_size = (i_ibytes_len - input_offset) > rate	? rate : i_ibytes_len - input_offset;
			S_ABSB_KECCAK	: block_size = 0;
			S_SQUZ			: block_size = (obytes_len > rate) 					? rate : obytes_len;
			S_IDLE			,
			S_DONE			: block_size = 0;
			default			: block_size = block_size;
		endcase
	end

	assign	block_size_mod	= |block_size[2:0] ? {block_size[7:3], 3'b0} + 8 : block_size;


	always @(posedge i_clk or negedge i_rstn) begin
		if (!i_rstn) begin
			input_offset	<= 0;
		end else begin
			case (c_state)
				S_ABSB		: input_offset	<= block_last ? input_offset + block_size : input_offset;
				S_DONE		: input_offset	<= 0;
				default		: input_offset	<= input_offset;
			endcase
		end
	end

	always @(*) begin
		case (c_state)
			S_ABSB		: o_ibytes_ready	= n_state == S_ABSB ? 1 : 0;
			default		: o_ibytes_ready	= 0;
		endcase
	end

	always @(*) begin
		case (c_state)
			S_DONE		: o_obytes_done		= 1;
			default		: o_obytes_done		= 0;
		endcase
	end

// --------------------------------------------------
//	KeccakF1600
// --------------------------------------------------
	wire 		[1600-1:0]	keccak_ostate;
	wire 					keccak_ostate_valid;
	wire 					keccak_istate_ready;
	reg			[1600-1:0]	keccak_istate;
	reg						keccak_istate_valid;

	always @(posedge i_clk or negedge i_rstn) begin
		if (!i_rstn) begin
			keccak_istate	<= 0;
		end else begin
			case (c_state)
				S_DONE			:	keccak_istate									<= 0;
				S_ABSB			:	begin
								if (p_state == S_ABSB) begin
										keccak_istate[1600-1-64*(cnt_block)-:64]	<= keccak_istate[1600-1-64*(cnt_block)-:64] ^ i_ibytes;
								end else begin
									keccak_istate									<= keccak_istate;
								end
				end
				S_PADD_KECCAK	:	begin
								if (p_state != S_PADD_KECCAK) begin
									keccak_istate[1600-1-block_size*8-:8]			<= keccak_istate[1600-1-block_size*8-:8] ^ suffix		;
									keccak_istate[1600-1-(rate-1)*8-:8]				<= keccak_istate[1600-1-(rate-1)*8-:8]   ^ 8'h80		;
								end else begin
									keccak_istate									<= keccak_ostate;
								end
				end
				S_ABSB_KECCAK	,
				S_SQUZ_KECCAK	:	keccak_istate									<= keccak_ostate;
				default			:	keccak_istate									<= keccak_istate;
			endcase
		end
	end

	always @(*) begin
		case (n_state)
			S_PADD_KECCAK	:	keccak_istate_valid	= c_state == S_PADD_KECCAK ? 1 : 0;
			S_ABSB_KECCAK	,	
			S_SQUZ_KECCAK	:	keccak_istate_valid	= 1;
			default			:	keccak_istate_valid	= 0;
		endcase
	end

	keccakf1600
	u_keccakf1600(
		.o_ostate			(keccak_ostate			),
		.o_ostate_valid		(keccak_ostate_valid	),
		.o_istate_ready		(keccak_istate_ready	),
		.i_istate			(keccak_istate			),
		.i_istate_valid		(keccak_istate_valid	),
		.i_clk				(i_clk					),
		.i_rstn				(i_rstn					)
	);

// --------------------------------------------------
//	Output Bytes
// --------------------------------------------------
	always @(posedge i_clk or negedge i_rstn) begin
		if (!i_rstn) begin
			o_obytes		<= 0;
			o_obytes_valid	<= 0;
		end else begin
			if (c_state == S_SQUZ) begin
				o_obytes		<= keccak_istate[1600-1-64*(cnt_block)-:64];
				o_obytes_valid	<= 1;
			end else begin
				o_obytes		<= o_obytes;
				o_obytes_valid	<= 0;
			end
		end
	end


	`ifdef DEBUG
	reg			[127:0]			ASCII_C_STATE;
	always @(*) begin
		case (c_state)
			S_IDLE			: ASCII_C_STATE = "IDLE       ";
			S_ABSB			: ASCII_C_STATE = "ABSB       ";
			S_ABSB_KECCAK	: ASCII_C_STATE = "ABSB_KECCAK";
			S_PADD_KECCAK	: ASCII_C_STATE = "PADD_KECCAK";
			S_SQUZ			: ASCII_C_STATE = "SQUZ       ";
			S_SQUZ_KECCAK	: ASCII_C_STATE = "SQUZ_KECCAK";
			S_DONE			: ASCII_C_STATE = "DONE       ";
		endcase
	end

	`endif

endmodule
