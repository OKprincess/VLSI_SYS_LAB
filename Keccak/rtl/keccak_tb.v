// ==================================================
//	[ VLSISYS Lab. ]
//	* Author		: Woong Choi (woongchoi@sm.ac.kr)
//	* Filename		: keccak_tb.v
//	* Description	: 
// ==================================================

// --------------------------------------------------
//	Define Global Variables
// --------------------------------------------------
`define	CLKFREQ		100		// Clock Freq. (Unit: MHz)
`define	SIMCYCLE	`NVEC	// Sim. Cycles
`define NVEC		500		// # of Test Vector
`define	DEBUG
`define	FINISH		200000

// --------------------------------------------------
//	Infomation
// --------------------------------------------------
//	Maximum InputBytes		: 1184 B
//	Maximum InputBlock		:  168 B
//	Maximum OutputBytes		:  784 B
//	Cycles for InputBlock	:  168 B / 64 b = 21 Cycles

// --------------------------------------------------
//	Includes
// --------------------------------------------------
`include	"keccak.v"

module keccak_tb;
// --------------------------------------------------
//	DUT Signals & Instantiate
// --------------------------------------------------
	wire	[64-1:0]		o_obytes;
	wire					o_obytes_done;
	wire					o_obytes_valid;
	wire					o_ibytes_ready;
	reg		[   1:0]		i_mode;
	reg		[64-1:0]		i_ibytes;
	reg						i_ibytes_valid;
	reg		[11-1:0]		i_ibytes_len;
	reg		[10-1:0]		i_obytes_len;
	reg						i_clk;
	reg						i_rstn;

	reg		[1568*8-1:0]	IBYTES;
	reg		[ 768*8-1:0]	OBYTES;
	reg		[ 10:0]			cnt_in;
	reg		[ 10:0]			cnt_ou;
	wire	[11-1:0]		ibytes_len;

	assign	ibytes_len = |i_ibytes_len[2:0] ? {i_ibytes_len[10:3], 3'b0} + 8 : i_ibytes_len;

	always @(posedge i_clk or negedge i_rstn) begin
		if (!i_rstn) begin
			i_ibytes	<= 0;
			cnt_in		<= 0;
			IBYTES		<= 0;
		end else begin
			if ((i_ibytes_valid && o_ibytes_ready)) begin
				i_ibytes								<= vi_ibytes[i][ibytes_len*8-1-(64*cnt_in)-:64];
				cnt_in									<= cnt_in + 1;
				IBYTES[ibytes_len*8-1-(64*cnt_in)-:64]	<= vi_ibytes[i][ibytes_len*8-1-(64*cnt_in)-:64];
			end else begin
				if (u_keccak.c_state == 6) begin
					i_ibytes	<= 0;
					cnt_in		<= 0;
					IBYTES		<= IBYTES;
				end else begin
					i_ibytes	<= i_ibytes;
					cnt_in		<= cnt_in;
					IBYTES		<= IBYTES;
				end
			end
		end
	end

	keccak
	u_keccak(
		.o_obytes			(o_obytes			),
		.o_obytes_done		(o_obytes_done		),
		.o_obytes_valid		(o_obytes_valid		),
		.o_ibytes_ready		(o_ibytes_ready		),
		.i_mode				(i_mode				),
		.i_ibytes			(i_ibytes			),
		.i_ibytes_valid		(i_ibytes_valid		),
		.i_ibytes_len		(i_ibytes_len		),
		.i_obytes_len		(i_obytes_len		),
		.i_clk				(i_clk				),
		.i_rstn				(i_rstn				)
	);

	always @(posedge i_clk or negedge i_rstn) begin
		if (!i_rstn) begin
			OBYTES		<= 0;
			cnt_ou		<= 0;
		end else begin
			if (o_obytes_valid) begin
				OBYTES[i_obytes_len*8-1-64*(cnt_ou)-:64]	<= o_obytes;
				cnt_ou		<= cnt_ou + 1;
			end else begin
				if (u_keccak.c_state == 0) begin
					OBYTES		<= 0;
					cnt_ou		<= 0;
				end else begin
					OBYTES		<= OBYTES;
					cnt_ou		<= cnt_ou;
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
	reg		[       1:0]	vi_mode      [0:`NVEC-1];
	reg		[1568*8-1:0]	vi_ibytes    [0:`NVEC-1];
	reg		[ 784*8-1:0]	vo_obytes    [0:`NVEC-1];
	reg		[    11-1:0]	vi_ibytes_len[0:`NVEC-1];
	reg		[    10-1:0]	vi_obytes_len[0:`NVEC-1];

	initial begin
		$readmemh("../vec/keccak/i_mode.vec",		vi_mode       ) ;
		$readmemh("../vec/keccak/i_ibytes.vec",		vi_ibytes     ) ;
		$readmemh("../vec/keccak/o_obytes.vec",		vo_obytes     ) ;
		$readmemh("../vec/keccak/i_ibytes_len.vec",	vi_ibytes_len ) ;
		$readmemh("../vec/keccak/i_obytes_len.vec",	vi_obytes_len ) ;
	end

// --------------------------------------------------
//	Tasks
// --------------------------------------------------
	reg		[4*32-1:0]	taskState;
	integer				err	= 0;

	task init;
		begin
			taskState		= "Init";
			i_mode			= 0;
			i_ibytes		= 0;
			i_ibytes_valid	= 0;
			i_ibytes_len	= 0;
			i_obytes_len	= 0;
			i_clk			= 1;
			i_rstn			= 0;
			cnt_in			= 0;
		end
	endtask

	task resetNCycle;
		input	[9:0]	i;
		begin
			taskState	= "Reset";
			i_rstn		= 1'b0;
			#(i*1000/`CLKFREQ);
			i_rstn		= 1'b1;
		end
	endtask

	task vecInsert;
		input	[$clog2(`NVEC)-1:0]	i;
		begin
			$sformat(taskState,	"VEC[%3d]", i);
			i_mode			= vi_mode[i];
			i_ibytes_len	= vi_ibytes_len[i];
			i_obytes_len	= vi_obytes_len[i];
			i_ibytes_valid	= 1;
		end
	endtask

	task vecVerify;
		input	[$clog2(`NVEC)-1:0]	i;
		begin
			#(0.1*1000/`CLKFREQ);
			if (	OBYTES != vo_obytes[i])  begin $display("[Idx: %3d] Mismatched o_obytes", i); end
			if ((	OBYTES != vo_obytes[i])) begin err++; end
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
			@ (negedge o_obytes_done) begin
				i_ibytes_valid	= 0;
				#(100/`CLKFREQ);
				vecVerify(i);
			end
			#(10*1000/`CLKFREQ);
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
			$dumpfile("keccak_tb.vcd");
			$dumpvars;
		end
		#(`FINISH*1000/`CLKFREQ)	$finish;
	end

endmodule
