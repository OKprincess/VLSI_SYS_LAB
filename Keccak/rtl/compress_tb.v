// ==================================================
//	[ VLSISYS Lab. ]
//	* Author		: Woong Choi (woongchoi@sm.ac.kr)
//	* Filename		: compress_tb.v
//	* Description	: 
// ==================================================

// --------------------------------------------------
//	Define Global Variables
// --------------------------------------------------
`define	CLKFREQ		100		// Clock Freq. (Unit: MHz)
`define	SIMCYCLE	`NVEC	// Sim. Cycles
`define NVEC		100		// # of Test Vector

// --------------------------------------------------
//	Includes
// --------------------------------------------------
`include	"compress.v"

module compress_tb;
// --------------------------------------------------
//	DUT Signals & Instantiate
// --------------------------------------------------

	wire	[10:0]		o_coeff;
	reg		[12:0]		i_coeff;
	reg		[ 3:0]		i_d;

	compress
	u_compress(
		.o_coeff		(o_coeff			),
		.i_coeff		(i_coeff			),
		.i_d			(i_d				)
	);

// --------------------------------------------------
//	Test Vector Configuration
// --------------------------------------------------
	reg		[13*256-1:0]		vo_coeff	[0:`NVEC-1];
	reg		[13*256-1:0]		vi_coeff	[0:`NVEC-1];
	reg		[13*256-1:0]		vi_d		[0:`NVEC-1];

	initial begin
		$readmemh("../vec/compress/o_coeffs.vec",		vo_coeff);
		$readmemh("../vec/compress/i_coeffs.vec",		vi_coeff);
		$readmemh("../vec/compress/i_d.vec",			vi_d);
	end

// --------------------------------------------------
//	Tasks
// --------------------------------------------------
	reg		[4*32-1:0]	taskState;
	integer				err	= 0;

	task init;
		begin
			taskState		= "Init";
			i_coeff				= 0;
			i_d					= 0;
		end
	endtask

	task vecInsert;
		input	[$clog2(`NVEC)-1:0]	i;
		input	[$clog2(  256)-1:0]	j;
		begin
			$sformat(taskState,	"VEC[%3d][%3d]", i, j);
			i_coeff				= vi_coeff[i][13*256-1-j*13-:13];
			i_d					= vi_d[i];
		end
	endtask

	task vecVerify;
		input	[$clog2(`NVEC)-1:0]	i;
		input	[$clog2(  256)-1:0]	j;
		begin
			#(0.1*1000/`CLKFREQ);
			if (o_coeff	!= vo_coeff[i][13*256-1-j*13-:13]) begin $display("[Idx: %3d] Mismatched o_coeff", i); end
			if (o_coeff != vo_coeff[i][13*256-1-j*13-:13]) begin err++; end
			#(0.9*1000/`CLKFREQ);
		end
	endtask

// --------------------------------------------------
//	Test Stimulus
// --------------------------------------------------
	integer		i, j;
	initial begin
		init();

		for (i=0; i<`SIMCYCLE; i++) begin
			for (j=0; j<256; j++) begin
				vecInsert(i,j);
				vecVerify(i,j);
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
			$dumpfile("compress_tb.vcd");
			$dumpvars;
		end
	end

endmodule
