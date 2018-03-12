initial begin : test
 integer i;
 parameter IFMAP_LEN = 1024;
 parameter OFMAP_LEN = 2048;
 parameter BURST_LEN = 4;
 parameter WIDTH = 32;
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

 for(i = 0; i < IFMAP_LEN*PRECISION/BURST_LEN/WIDTH; i = i + 1) begin
	 status = "WRITE";
	 ca_i = 4*i;
	 w0 = $random;
	 w1 = $random;
	 w2 = $random;
	 w3 = $random;
 	 $display ("%m at time %t: Write %d to CA[]=0x%h", $time, i, ca_i);
 	 write(0, ca_i, 0, 0, {w0[31:0], w2[31:0], w1[31:0], w0[31:0]});
	 nop(tccd-1);
 end
 //activate(0, 0);
 nop(twtr+2);

 for(i = 0; i < IFMAP_LEN*PRECISION/BURST_LEN/WIDTH; i = i+1) begin
 	 $display ("%m at time %t: Read %d to CA[]=0x%h", $time, i, ca_i);
	 status = "READ";
	 ca_i = 4*i;
	 read(0, ca_i[9:0], 0);
	 nop(tccd-1);
 end
 status = "NOP-RL";
 nop(rl+1);
 status = "NOP";
 nop(2);
 test_done;
end

