initial begin : test
 integer i;
 parameter FMAP_LEN0 = 1024;
 parameter FMAP_LEN1 = 2048;
 parameter FMAP_LEN2 = 2048;
 parameter FMAP_LEN3 = 1024;
 parameter FMAP_LEN4 = 512;
 parameter BURST_LEN = 4;
 parameter PRECISION = 8;
 reg [8*12:1] status;
 reg [9:0] ca_i;
 reg [31:0] w0;
 reg [31:0] w1;
 reg [31:0] w2;
 reg [31:0] w3;
 $display ("%m at time %t: Power Ramp and Initialization Sequence", $time);
 status = "POWERUP";
 power_up;

 $display ("%m at time %t: Mode Register Read timing example", $time);
 status = "MRR";
 mode_reg_read (0); nop(tmrr - 1);
 mode_reg_read (1); nop(tmrr - 1);
 mode_reg_read (2); nop(tmrr - 1);
 mode_reg_read (3); nop(tmrr - 1);
 mode_reg_read (4); nop(tmrr - 1);
 mode_reg_read (5); nop(tmrr - 1);
 mode_reg_read (6); nop(tmrr - 1);
 mode_reg_read (7); nop(tmrr - 1);
 mode_reg_read (8); nop(tmrr - 1);

 $display ("%m at time %t: Activate", $time);
 status = "ACTIVATE";
 activate(0, 0);
 status = "NOP";
 nop(trcd-1);

 status = "WRITE";
 ca_i = 10'd0;
	 w0 = 4'h0001;
	 w1 = 4'h0002;
	 w2 = 4'h0003;
	 w3 = 4'h0004;
 	 $display ("%m at time %t: Write %d to CA[]=0x%h", $time, i, ca_i);
 	 write(0, ca_i, 0, 0, {w0[DQ_BITS-1:0], w1[DQ_BITS-1:0], w2[DQ_BITS-1:0], w3[DQ_BITS-1:0]});
 status = "NOP-WL";
 nop(wl);
 status = "NOP-BL";
 nop(bl/2);
 status = "NOP-TWTR";
 nop(twtr);
 read(0, ca_i+3, 0);

 status = "NOP";
 nop(10);
 test_done;
end

