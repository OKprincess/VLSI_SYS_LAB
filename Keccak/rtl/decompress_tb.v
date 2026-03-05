// ==================================================
//	[ VLSISYS Lab. ]
//	* Author		: Woong Choi (woongchoi@sm.ac.kr)
//	* Filename		: decompress_tb.v
//	* Description	: 
// ==================================================

// --------------------------------------------------
//	Define Global Variables
// --------------------------------------------------
`define	CLKFREQ		100		// Clock Freq. (Unit: MHz)
`define	SIMCYCLE	`NVEC	// Sim. Cycles
`define NVEC		10		// # of Test Vector

// --------------------------------------------------
//	Includes
// --------------------------------------------------
`include	"decompress.v"

module decompress_tb;
// --------------------------------------------------
//	DUT Signals & Instantiate
// --------------------------------------------------
	wire	[11:0]		o_coeff;
	reg		[10:0]		i_coeff;
	reg		[ 3:0]		i_d;

	decompress
	u_decompress(
		.o_coeff			(o_coeff			),
		.i_coeff			(i_coeff			),
		.i_d				(i_d				)
	);

// --------------------------------------------------
//	Test Vector Configuration
// --------------------------------------------------
	reg		[12*256-1:0]	vo_coeff[0:`NVEC-1];
	reg		[12*256-1:0]	vi_coeff[0:`NVEC-1];
	reg		[12*256-1:0]	vi_d[0:`NVEC-1];

	initial begin
		$readmemh("../vec/decompress/o_coeffs.vec",		vo_coeff);
		$readmemh("../vec/decompress/i_coeffs.vec",		vi_coeff);
		$readmemh("../vec/decompress/i_d.vec",			vi_d);
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
			$sformat(taskState,	"VEC[%3d]", i);
			i_coeff				= vi_coeff[i][12*256-1-j*12-:12];
			i_d					= vi_d[i];
		end
	endtask

	task vecVerify;
		input	[$clog2(`NVEC)-1:0]	i;
		input	[$clog2(  256)-1:0]	j;
		begin
			#(0.1*1000/`CLKFREQ);
			if (o_coeff	!= vo_coeff[i][12*256-1-j*12-:12]) begin $display("[Idx: %3d] Mismatched o_coeff", i); end
			if (o_coeff != vo_coeff[i][12*256-1-j*12-:12]) begin err++; end
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
			$dumpfile("decompress_tb.vcd");
			$dumpvars;
		end
	end

endmodule
