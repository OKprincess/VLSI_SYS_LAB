// ==================================================
//	[ VLSISYS Lab. ]
//	* Author		: Woong Choi (woongchoi@sm.ac.kr)
//	* Filename		: decode_tb.v
//	* Description	: 
// ==================================================

// --------------------------------------------------
//	Define Global Variables
// --------------------------------------------------
`define	CLKFREQ		100		// Clock Freq. (Unit: MHz)
`define	SIMCYCLE	`NVEC	// Sim. Cycles
`define NVEC		100		// # of Test Vector
`define	DEBUG

// --------------------------------------------------
//	Includes
// --------------------------------------------------
`include	"decode.v"

module decode_tb;
// --------------------------------------------------
//	DUT Signals & Instantiate
// --------------------------------------------------
	wire	[63:0]		o_coeffs;
	wire				o_coeffs_valid;
	wire				o_ibytes_ready;
	wire				o_done;
	reg		[63:0]		i_ibytes;
	reg					i_ibytes_valid;
	reg		[3:0]		i_l;
	reg					i_clk;
	reg					i_rstn;

	decode
	u_decode(
		.o_coeffs			(o_coeffs			),
		.o_coeffs_valid		(o_coeffs_valid		),
		.o_ibytes_ready		(o_ibytes_ready		),
		.o_done				(o_done				),
		.i_ibytes			(i_ibytes			),
		.i_ibytes_valid		(i_ibytes_valid		),
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
	reg		[256*12-1:0]		vo_coeffs[0:`NVEC-1];
	reg		[256*12-1:0]		vi_ibytes[0:`NVEC-1];
	reg		[256*12-1:0]		vi_l[0:`NVEC-1];

	initial begin
		$readmemh("../vec/decode/o_coeffs.vec",		vo_coeffs);
		$readmemh("../vec/decode/i_ibytes.vec",		vi_ibytes);
		$readmemh("../vec/decode/i_l.vec",			vi_l);
	end

// --------------------------------------------------
//	Tasks
// --------------------------------------------------
	reg		[4*32-1:0]	taskState;
	integer				err	= 0;

	task init;
		begin
			taskState		= "Init";
			i_ibytes		= 0;
			i_ibytes_valid	= 0;
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
			$sformat(taskState,	"VEC[%3d]", i);
			i_l				<= vi_l[i];
			i_ibytes_valid	<= 1;
			@ (posedge i_clk) begin
				if (i_ibytes_valid && o_ibytes_ready) begin
					if (j < i_l*32*8/64) begin
						i_ibytes	<= vi_ibytes[i][i_l*32*8-1-j*64-:64];
						j <= j+1;
					end else begin
						i_ibytes	<= 0;
					end
				end
			end
		end
	endtask

	task vecVerify;
		begin
			#(0.5*1000/`CLKFREQ);
			if (u_decode.o_coeffs_debug != vo_coeffs[i]) begin $display("[Idx: %3d] Mismatched o_coeffs", i); end
			if (u_decode.o_coeffs_debug != vo_coeffs[i]) begin err++; end
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
			j = 0;
			//for (j=0; j<(384*8/64); j++) begin
			while (!o_done) begin
				vecInsert;
				#(1000/`CLKFREQ);
			end
//			@ (posedge o_done) begin
			i_ibytes_valid	<= 0;
			vecVerify;
			#(4000/`CLKFREQ);
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
			$dumpfile("decode_tb.vcd");
			$dumpvars;
		end
	end

endmodule
