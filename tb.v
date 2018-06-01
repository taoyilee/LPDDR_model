`timescale 1ps / 1ps

module tb;

`include "lpddr2_1GB_x16.v"

    // ports
    reg                         ck;
    wire                        ck_n = ~ck;
    reg                         cke;
    reg                         cs_n;
    reg           [CA_BITS-1:0] ca;
    reg           [DM_BITS-1:0] dm;
    wire          [DQ_BITS-1:0] dq;
    wire         [DQS_BITS-1:0] dqs;
    wire         [DQS_BITS-1:0] dqs_n;

    // mode registers
    reg                   [7:0] mr1;
    reg                   [7:0] mr2;
    wire                  [4:0] bl  = 4;
    wire                  [3:0] rl = 3;
    wire                  [2:0] wl = 1;

    // dq transmit
    reg                         dq_en;
    reg           [DQ_BITS-1:0] dq_out;
    reg                         dqs_en;
    reg          [DQS_BITS-1:0] dqs_out;
    assign                      dq       = dq_en ? dq_out : {DQ_BITS{1'bz}};
    assign                      dqs      = dqs_en ? dqs_out : {DQS_BITS{1'bz}};
    assign                      dqs_n    = dqs_en ? ~dqs_out : {DQS_BITS{1'bz}};

    // dq receive
    reg           [DM_BITS-1:0] dm_fifo [2*CL_MAX+24:0];
    reg           [DQ_BITS-1:0] dq_fifo [2*CL_MAX+24:0];
    wire          [DQ_BITS-1:0] q0, q1, q2, q3, q4, q5, q6, q7, q8, q9, q10, q11, q12, q13, q14, q15;
    reg                         ptr_rst_n;
    reg                   [3:0] burst_cntr;

    // timing definition in tCK units
    real                        tck;
    wire                 [11:0] tdqsck   = ceil(TDQSCK_MAX/tck);
    wire                 [11:0] tcke     = CKE;
    wire                 [11:0] tckesr   = ceil(TCKESR/tck);
    wire                 [11:0] tmrr     = MRR;
    wire                 [11:0] tmrw     = MRW;
    wire                 [11:0] tccd     = CCD;
    wire                 [11:0] tfaw     = max(ceil(TFAW/tck), FAW);
    wire                 [11:0] tras     = max(ceil(TRAS/tck), RAS);
    wire                 [11:0] trcd     = max(ceil(TRCD/tck), RCD);
    wire                 [11:0] trpab    = max(ceil(TRPAB/tck), RPAB);
    wire                 [11:0] trppb    = max(ceil(TRPPB/tck), RPPB);
    wire                 [11:0] trrd     = max(ceil(TRRD/tck), RRD);
    wire                 [11:0] trtp     = max(ceil(TRTP/tck), RTP);
    wire                 [11:0] twr      = max(ceil(TWR/tck), WR);
    wire                 [11:0] twtr     = max(ceil(TWTR/tck), WTR);
    wire                 [11:0] txp      = max(ceil(TXP/tck), XP);
    wire                 [11:0] txsr     = ceil(TXSR/tck);
    wire                 [11:0] trfcpb   = ceil(TRFCPB/tck);
    wire                 [11:0] trfcab   = ceil(TRFCAB/tck);

    real                        init_speed;


    initial begin
        $timeformat (-9, 1, " ns", 1);
`ifdef period
        tck <= `period; 
`else
        tck <= TCK_MIN;
`endif
        ck <= 1'b1;
        dm <= {DM_BITS{1'b0}};
        dqs_en <= 1'b0;
        dq_en <= 1'b0;
        init_speed = 1.0;
		$dumpfile("tb.vcd");
	    $dumpvars(0);
    end

    // component instantiation
    mobile_ddr2 sdrammobile_ddr2 (
        ck,
        ck_n,
        cke,
        cs_n,
        ca,
        dm,
        dq,
        dqs,
        dqs_n
    );

    // clock generator
    always @(posedge ck) begin
      ck <= #(tck/2) 1'b0;
      ck <= #(tck) 1'b1;
    end

    function integer ceil;
        input number;
        real number;
        if (number > $rtoi(number))
            ceil = $rtoi(number) + 1;
        else
            ceil = number;
    endfunction

    function integer max;
        input arg1;
        input arg2;
        integer arg1;
        integer arg2;
        if (arg1 > arg2)
            max = arg1;
        else
            max = arg2;
    endfunction

    task power_up;
        real previous_tck;
        begin
            if (init_speed > 1.0) begin
                $display ("%m at time %t: INFO: The initialization sequence will run at %0.2fx.  tINIT errors are expected.", $time, init_speed);
            end
            power_down (2);                                                             // provide 2 clocks with CKE low
            previous_tck <= tck;
            tck = 100000;                                                               // change clock period to 100 ns
            @(posedge ck);
            @(negedge ck);
            power_down (max(ceil(TINIT1/init_speed/tck), ceil(INIT2/init_speed)));      // satisfy tINIT1 and INIT2
            deselect (ceil(TINIT3/init_speed/tck));                                     // satisfy tINIT3
            precharge (0,1); // PREab allowed 
            deselect (10);
            mode_reg_write(8'h3F, 8'h0);                                                // issue reset command
            deselect (max(ceil(TINIT4/init_speed/tck), ceil(TINIT5/init_speed/tck)));   // satisfy tINIT4 and tINIT5
            mode_reg_write(8'h0a, 8'hFF);                                               // issue ZQ Calibration command
            deselect (ceil(TZQINIT/init_speed/tck));                                    // satisfy tZQINIT
            power_down (2);                                                             // provide 2 clocks with CKE low
            tck = previous_tck;                                                         // restore original clock period;
            @(posedge ck);
            @(negedge ck);
            power_down (ceil(INIT2/init_speed));
            deselect (txp);

        end
    endtask

    task mode_reg_write;
        input                 [7:0] ma;
        input                 [7:0] op;
        begin
            cke   <= 1'b1;
            cs_n  <= 1'b0;
            ca    <= #(tck/4) {ma[5:0], 4'h0};
            ca    <= #(3*tck/4) {op, ma[7:6]};
            case (ma)
                1: mr1 <= op;
                2: mr2 <= op;
            endcase
            @(negedge ck);
        end
    endtask

    task mode_reg_read;
        input                 [7:0] ma;
        integer i;
        begin
            cke   <= 1'b1;
            cs_n  <= 1'b0;
            ca    <= #(tck/4) {ma[5:0], 4'h8};
            ca    <= #(3*tck/4) ma[7:6];
            @(negedge ck);
        end
    endtask

    task refresh;
        input                       ab;
        begin
            cke   <= 1'b1;
            cs_n  <= 1'b0;
            ca    <= #(tck/4) {ab, 3'h4};
            @(negedge ck);
        end
    endtask
     
    task precharge;
        input         [BA_BITS-1:0] ba;
        input                       ab;
        begin
            cke   <= 1'b1;
            cs_n  <= 1'b0;
            ca    <= #(tck/4) {ba, 2'h0, ab, 4'hB};
            @(negedge ck);
        end
    endtask
     
    task activate;
        input         [BA_BITS-1:0] ba;
        input                [14:0] r;
        begin
            cke   <= 1'b1;
            cs_n  <= 1'b0;
            ca    <= #(tck/4) {ba, r[12:8], 2'h2};
            ca    <= #(3*tck/4) {r[14:13], r[7:0]};
            @(negedge ck);
        end
    endtask

    //write task supports burst lengths <= 16
    task write;
        input         [BA_BITS-1:0] ba;
        input                [11:0] c;
        input                       ap;
        input      [4*DM_BITS-1:0] wdm;
        input      [4*DQ_BITS-1:0] wdq;
        integer i;
        integer dly;
        begin
            cke   <= 1'b1;
            cs_n  <= 1'b0;
            ca    <= #(tck/4) {ba, c[2:1], 2'h0, 3'h1};
            ca    <= #(3*tck/4) {c[11:3], ap};

            for (i=0; i<=bl; i=i+1) begin
                dly = (wl + 1)*tck + i*tck/2;
                dqs_en <= #(dly) 1'b1;
                if (i%2 == 0) begin
                    dqs_out <= #(dly) {DQS_BITS{1'b0}};
                end else begin
                    dqs_out <= #(dly) {DQS_BITS{1'b1}};
                end

                dq_en  <= #(dly + tck/4) 1'b1;
                dm     <= #(dly + tck/4) wdm>>i*DM_BITS;
                dq_out <= #(dly + tck/4) wdq>>i*DQ_BITS;
            end
            dly = (wl + 1)*tck + bl*tck/2;
            dqs_en <= #(dly + tck/2) 1'b0;
            dq_en  <= #(dly + tck/4) 1'b0;
            @(negedge ck);  
        end
    endtask

    // read without data verification
    task read;
        input         [BA_BITS-1:0] ba;
        input                [11:0] c;
        input                       ap;
        begin
            cke   <= 1'b1;
            cs_n  <= 1'b0;
            ca    <= #(tck/4) {ba, c[2:1], 2'h0, 3'h5};
            ca    <= #(3*tck/4) {c[11:3], ap};
            @(negedge ck);
        end
    endtask

    task burst_term;
        integer i;
        begin
            cke   <= 1'b1;
            ca    <= #(tck/4) 4'h3;
            @(negedge ck);
            for (i=0; i<bl; i=i+1) begin
                dm_fifo[2*(rl + 3) + i] <= {DM_BITS{1'bx}};
                dq_fifo[2*(rl + 3) + i] <= {DQ_BITS{1'bx}};
            end
        end
    endtask

    task nop;
        input [31:0] count;
        begin
            cke   <= 1'b1;
            cs_n  <= 1'b0;
            ca    <= #(tck/4) 3'h7;
            repeat(count) @(negedge ck);
        end
    endtask

    task deselect;
        input [31:0] count;
        begin
            cke   <= 1'b1;
            cs_n  <= 1'b1;
            ca    <= #(tck/4) 3'h7;
            repeat(count) @(negedge ck);
        end
    endtask

    task power_down;
        input [31:0] count;
        begin
            cke   <= 1'b0;
            cs_n  <= 1'b1;
            repeat(count) @(negedge ck);
        end
    endtask

    task self_refresh;
        input [31:0] count;
        begin
            cke   <= 1'b0;
            cs_n  <= 1'b0;
            ca    <= #(tck/4) 3'h4;
            cs_n  <= #(tck) 1'b1;
            repeat(count) @(negedge ck);
        end
    endtask

    task deep_power_down;
        input [31:0] count;
        begin
            cke   <= 1'b0;
            cs_n  <= 1'b0;
            ca    <= #(tck/4) 3'h3;
            cs_n  <= #(tck) 1'b1;
            repeat(count) @(negedge ck);
        end
    endtask

    // End-of-test triggered in 'subtest.vh'
    task test_done;
        begin
            $display ("%m at time %t: INFO: Simulation is Complete", $time);
            $stop(0);
        end
    endtask

    // Test included from external file
    `include "subtest_simple.v"

endmodule

