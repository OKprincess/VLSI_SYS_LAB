// ==================================================
//	[ VLSISYS Lab. ]
//	* Author		: Woong Choi (woongchoi@sm.ac.kr)
//	* Filename		: encode_tb.v
//	* Date			: 2025-05-11 00:05:09
//	* Description	: 
// ==================================================

// --------------------------------------------------
//	Define Global Variables
// --------------------------------------------------
`define	CLKFREQ		100		// Clock Freq. (Unit: MHz)
`define	SIMCYCLE	`NVEC	// Sim. Cycles
`define NVEC		88		// # of Test Vector
`define	DEBUG

// --------------------------------------------------
//	Includes
// --------------------------------------------------
`include	"encode.v"

module encode_tb;
// --------------------------------------------------
//	DUT Signals & Instantiate
// --------------------------------------------------
	wire	[63:0]		o_obytes;
	wire				o_obytes_valid;
	wire				o_done;
	reg		[23:0]		i_coeffs;
	reg					i_coeffs_valid;
	reg		[3:0]		i_l;
	reg					i_clk;
	reg					i_rstn;

	encode
	u_encode(
		.o_obytes			(o_obytes			),
		.o_obytes_valid		(o_obytes_valid		),
		.o_done				(o_done				),
		.i_coeffs			(i_coeffs			),
		.i_coeffs_valid		(i_coeffs_valid		),
		.i_l				(i_l				),
		.i_clk				(i_clk				),
		.i_rstn				(i_rstn				)
	);

// --------------------------------------------------
//	Clock
// --------------------------------------------------
	always	#(500/`CLKFREQ)		i_clk = ~i_clk;

// --------------------------------------------------
//	Test Vector Configuration
// --------------------------------------------------
	reg		[256*12-1:0]		vo_obytes[0:`NVEC-1];
	reg		[256*12-1:0]		vi_coeffs[0:`NVEC-1];
	reg		[256*12-1:0]		vi_l[0:`NVEC-1];

	initial begin
		$readmemh("../vec/encode/o_obytes.vec",		vo_obytes);
		$readmemh("../vec/encode/i_coeffs.vec",		vi_coeffs);
		$readmemh("../vec/encode/i_l.vec",			vi_l);
	end

// --------------------------------------------------
//	Tasks
// --------------------------------------------------
	reg		[4*32-1:0]	taskState;
	integer				err	= 0;

	task init;
		begin
			taskState		= "Init";
			i_coeffs		= 0;
			i_coeffs_valid	= 0;
			i_l				= 0;
			i_clk			= 1;
			i_rstn			= 0;
		end
	endtask

	task resetNCycle;
		input	[9:0]	i;
		begin
			taskState		= "Reset";
			i_rstn	= 1'b0;
			#(i*1000/`CLKFREQ);
			i_rstn	= 1'b1;
		end
	endtask

	task vecInsert;
		begin
			$sformat(taskState,	"VEC[%2d/%2d]", i, j);
			i_l				= vi_l[i];
			i_coeffs_valid	= 1;
			@ (posedge i_clk) begin
				if (i_coeffs_valid) begin
					i_coeffs = vi_coeffs[i][12*256-1-12*2*j-:12*2];
				end
				//case(i_l)
				//	 1: i_coeffs = vi_coeffs[i][ 1*256-1- 1*2*j-: 1*2];
				//	 4: i_coeffs = vi_coeffs[i][ 4*256-1- 4*2*j-: 4*2];
				//	 5: i_coeffs = vi_coeffs[i][ 5*256-1- 5*2*j-: 5*2];
				//	10: i_coeffs = vi_coeffs[i][10*256-1-10*2*j-:10*2];
				//	11: i_coeffs = vi_coeffs[i][11*256-1-11*2*j-:11*2];
				//	12: i_coeffs = vi_coeffs[i][12*256-1-12*2*j-:12*2];
				//endcase
			end
		end
	endtask

	task vecVerify;
		begin
			i_coeffs_valid	= 0;
			#(0.5*1000/`CLKFREQ);
			if (u_encode.o_obytes_debug != vo_obytes[i]) begin $display("[Idx: %3d] Mismatched o_coeffs", i); end
			if (u_encode.o_obytes_debug != vo_obytes[i]) begin err++; end
			#(0.5*1000/`CLKFREQ);
		end
	endtask
// --------------------------------------------------
//	Test Stimulus
// --------------------------------------------------
	integer		i, j;
	initial begin
		init();
		resetNCycle(4);
		#(4000/`CLKFREQ);
		for (i=0; i<`SIMCYCLE; i++) begin
			for (j=0; j<128; j++) begin
				vecInsert;
				#(1000/`CLKFREQ);
			end
			@ (posedge o_done) begin
				vecVerify;
			end
		end
		#(1000/`CLKFREQ);
		$finish;
	end

// --------------------------------------------------
//	Dump VCD
// --------------------------------------------------
	reg	[8*32-1:0]	vcd_file;
	initial begin
		if ($value$plusargs("vcd_file=%s", vcd_file)) begin
			$dumpfile(vcd_file);
			$dumpvars;
		end else begin
			$dumpfile("encode_tb.vcd");
			$dumpvars;
		end
	end

endmodule
