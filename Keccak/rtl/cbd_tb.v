// ==================================================
//	[ VLSISYS Lab. ]
//	* Author		: Woong Choi (woongchoi@sm.ac.kr)
//	* Filename		: cbd_tb.v
//	* Description	: 
// ==================================================

// --------------------------------------------------
//	Define Global Variables
// --------------------------------------------------
`define	CLKFREQ		100		// Clock Freq. (Unit: MHz)
`define	SIMCYCLE	`NVEC	// Sim. Cycles
`define NVEC		500		// # of Test Vector
`define FINISH		20000	// # of Test Vector
`define	DEBUG

// --------------------------------------------------
//	Includes
// --------------------------------------------------
`include	"cbd.v"

module cbd_tb;
// --------------------------------------------------
//	DUT Signals & Instantiate
// --------------------------------------------------
	wire		[47:0]		o_coeffs;
	wire					o_coeffs_valid;
	wire					o_ibytes_ready;
	wire					o_done;
	reg			[63:0]		i_ibytes;
	reg						i_ibytes_valid;
	reg			[1:0]		i_eta;
	reg						i_clk;
	reg						i_rstn;

	cbd
	u_cbd(
		.o_coeffs			(o_coeffs			),
		.o_coeffs_valid		(o_coeffs_valid		),
		.o_ibytes_ready		(o_ibytes_ready		),
		.o_done				(o_done				),
		.i_ibytes			(i_ibytes			),
		.i_ibytes_valid		(i_ibytes_valid		),
		.i_eta				(i_eta				),
		.i_clk				(i_clk				),
		.i_rstn				(i_rstn				)
	);

	reg		[7:0]		cnt_in;
	always @(posedge i_clk or negedge i_rstn) begin
		if (!i_rstn) begin
			cnt_in		<= 0;
			i_ibytes	<= 0;
		end else begin
			if (i_ibytes_valid && o_ibytes_ready) begin
				cnt_in		<= (i_eta == 2 && cnt_in < 15) || (i_eta == 3 && cnt_in < 23) ?	cnt_in + 1 : cnt_in;
				i_ibytes	<= i_eta == 2	?	vi_ibytes[i][128*8-1-(64*cnt_in)-:64]	:
												vi_ibytes[i][192*8-1-(64*cnt_in)-:64]	;
			end else begin
				if (u_cbd.c_state == 5) begin
					cnt_in		<= 0;
					i_ibytes	<= 0;
				end else begin
					cnt_in		<= cnt_in;
					i_ibytes	<= 0;
				end
			end
		end
	end

// --------------------------------------------------
//	Clock
// --------------------------------------------------
	always	#(500/`CLKFREQ)		i_clk = ~i_clk;

// --------------------------------------------------
//	Test Vector Configuration
// --------------------------------------------------
	reg		[256*3-1:0]		vo_coeffs	[0:`NVEC-1];
	reg		[192*8-1:0]		vi_ibytes	[0:`NVEC-1];
	reg		[1:0]			vi_eta		[0:`NVEC-1];

	initial begin
		$readmemh("../vec/cbd/o_coeffs.vec",		vo_coeffs);
		$readmemh("../vec/cbd/i_ibytes.vec",		vi_ibytes);
		$readmemh("../vec/cbd/i_eta.vec",			vi_eta);
	end

// --------------------------------------------------
//	Tasks
// --------------------------------------------------
	reg		[4*32-1:0]	taskState;
	integer				err	= 0;

	task init;
		begin
			taskState		= "Init";
			i_eta			= 0;
			i_ibytes		= 0;
			i_ibytes_valid	= 0;
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
		input	[$clog2(`NVEC)-1:0]	i;
		begin
			$sformat(taskState,	"VEC[%3d]", i);
			@(posedge i_clk) begin
				i_ibytes_valid	= 1;
				i_eta			= vi_eta[i];
			end
		end
	endtask

	task vecVerify;
		input	[$clog2(`NVEC)-1:0]	i;
		begin
			#(0.1*1000/`CLKFREQ);
			if ( u_cbd.COEFFS != vo_coeffs[i]) begin $display("[Idx: %3d] Mismatched o_coeffs", i); end
			if ((u_cbd.COEFFS != vo_coeffs[i])) begin err++; end
			#(0.9*1000/`CLKFREQ);
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
			vecInsert(i);
			@(negedge o_done) begin
				i_ibytes_valid	= 0;
				vecVerify(i);
				#(8000/`CLKFREQ);
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
//			for (i=0; i<16; i++) begin
//				$dumpvars(0, u_cbd.coeffs[i]);
//			end
			$dumpvars;
		end else begin
			$dumpfile("cbd_tb.vcd");
			$dumpvars;
		end
		#(`FINISH*1000/`CLKFREQ)	$finish;
	end

endmodule
