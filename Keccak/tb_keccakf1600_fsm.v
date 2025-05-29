// ==================================================
//	[ VLSISYS Lab. ]
//	* Author		: Woong Choi (woongchoi@sm.ac.kr)
//	* Filename		: keccakf1600_tb.v
//	* Description	: 
// ==================================================

// --------------------------------------------------
//	Define Global Variables
// --------------------------------------------------
`define	CLKFREQ		100		// Clock Freq. (Unit: MHz)
`define	SIMCYCLE	`NVEC	// Sim. Cycles
`define NVEC		10		// # of Test Vector
`define	FINISH		20000
`define	DEBUG

// --------------------------------------------------
//	Includes
// --------------------------------------------------
`include	"keccakf1600.v"

module keccakf1600_tb;
// --------------------------------------------------
//	DUT Signals & Instantiate
// --------------------------------------------------
	wire	[1600-1:0]	o_ostate;
	wire				o_ostate_valid;
	wire				o_istate_ready;
	reg		[1600-1:0]	i_istate;
	reg					i_istate_valid;
	reg					i_clk;
	reg					i_rstn;

	keccakf1600
	u_keccakf1600(
		.o_ostate			(o_ostate			),
		.o_ostate_valid		(o_ostate_valid		),
		.o_istate_ready		(o_istate_ready		),
		.i_istate			(i_istate			),
		.i_istate_valid		(i_istate_valid		),
		.i_clk				(i_clk				),
		.i_rstn				(i_rstn				)
	);

	always @(posedge i_clk or negedge i_rstn) begin
		if (!i_rstn) begin
			i_istate	<= 0;
		end else begin
			if (i_istate_valid && o_istate_ready) begin
				i_istate	<= vi_istate[i];
			end else if (i_istate_valid) begin
				i_istate	<= o_ostate;
			end else begin
				i_istate	<= i_istate;
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
	reg 	[1600-1:0]	vo_ostate[0:`NVEC-1];
	reg		[1600-1:0]	vi_istate[0:`NVEC-1];

	initial begin
		$readmemh("../vec/keccakf1600/o_ostate.vec",		vo_ostate);
		$readmemh("../vec/keccakf1600/i_istate.vec",		vi_istate);
	end

// --------------------------------------------------
//	Tasks
// --------------------------------------------------
	reg		[4*32-1:0]	taskState;
	integer				err	= 0;

	task init;
		begin
			taskState		= "Init";
			i_istate		= 0;
			i_istate_valid	= 0;
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
			i_istate_valid	= 1;
		end
	endtask

	task vecVerify;
		input	[$clog2(`NVEC)-1:0]	i;
		begin
			#(0.1*1000/`CLKFREQ);
			if (o_ostate != vo_ostate[i]) begin $display("[Idx: %3d] Mismatched o_ostate", i); end
			if (o_ostate != vo_ostate[i]) begin err++; end
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
		#(8000/`CLKFREQ);
		for (i=0; i<`SIMCYCLE; i++) begin
			vecInsert(i);
			@(posedge o_ostate_valid) begin
				i_istate_valid	= 0;
				#(100/`CLKFREQ);
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
			$dumpvars;
		end else begin
			$dumpfile("keccakf1600_tb.vcd");
			$dumpvars;
		end
		#(`FINISH*1000/`CLKFREQ)	$finish;
	end

endmodule
