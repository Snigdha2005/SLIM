module generic_base_multiplier #(parameter base_mult = 10)(
    input clk,
    input en,
    input [base_mult-1:0] x1,
    input [base_mult-1:0] y1,
    input [base_mult-1:0] x2,
    input [base_mult-1:0] y2,
    input a_in,
    input b_in,
    input [base_mult-1:0] x,
    input [base_mult-1:0] y,
    output [2*base_mult:0] out
);
    reg [base_mult-1:0] x11;
    reg [base_mult-1:0] x21;
    reg [base_mult-1:0] y11;
    reg [base_mult-1:0] y21;
    reg [base_mult-1:0] x_1;
    reg [base_mult-1:0] y_1;
    reg a_in_x;
    reg b_in_x;
    reg en_1;
    always @(posedge clk) begin
        x11 <= x1;
        x21 <= x2;
        y11 <= y1;
        y21 <= y2;
        a_in_x <= a_in;
        b_in_x <= b_in;
        x_1 <= x;
        y_1 <= y;
        en_1 <= en;
    end
//    assign out = (en_1 == 1'b1)?(x_1 * y_1):(a_in_x == 0)? ((b_in_x == 0) ? x11 * y11 : x11 * y21) : ((b_in_x == 0) ? x21 * y11 : x21 * y21);
  wire [base_mult-1:0] sel_x = en_1 ? x_1 : (a_in_x ? x21 : x11); 
  wire [base_mult-1:0] sel_y = en_1 ? y_1 : (b_in_x ? y21 : y11); 
  assign out = sel_x * sel_y;  
//    assign out = (a_in == 0)? ((b_in == 0) ? x1 * y1 : x1 * y2) : ((b_in == 0) ? x2 * y1 : x2 * y2);
endmodule

module generic_multiplier #(parameter base_mult = 128, parameter interface_bits = 32, parameter bram_depth = 512)(
    input clk,
    input [$clog2(base_mult*bram_depth)+1:0] size,
    input [interface_bits-1:0] x,
    input [interface_bits-1:0] y,
//    output reg start,
//    output reg done,
   output [interface_bits-1:0] out,
    input reset,
    output reg [$clog2(bram_depth):0] carry
    );
    localparam num_clocks = base_mult / interface_bits;
    wire signed [$clog2(base_mult*bram_depth)+1:0] num_blocks;
    assign num_blocks = size / base_mult;
    
    reg [$clog2(base_mult*bram_depth)+1:0] prev_size;
    reg [base_mult-1:0] outf;
    wire [bram_depth-1:0] addra0, addra1;
    reg [bram_depth-1:0] addra00, addra01;
    reg [bram_depth-1:0] addra10, addra11;
    reg [base_mult-1:0] dina0, dina1;
    wire [base_mult-1:0] douta0, douta1;
//    reg [$clog2(bram_depth):0] carry1;
    wire [bram_depth-1:0] addrb0, addrb1;
    reg [bram_depth-1:0] addrb00, addrb01;
    reg [bram_depth-1:0] addrb10, addrb11;
    reg [base_mult-1:0] dinb0, dinb1;
    wire [base_mult-1:0] doutb0, doutb1;
    reg ena2 = 1'b1;
    reg ena1 = 1'b1;
    reg wein = 1'b1;
    reg [$clog2(base_mult*bram_depth)+1:0] p_a_idx = 0;
    reg [$clog2(base_mult*bram_depth)+1:0] p_b_idx = 0;
    reg a_in;
    reg b_in;
    reg [31:0] shift_pipe1, shift_pipe2, shift_pipe3;
    reg [base_mult-1:0] in1;
    reg [base_mult-1:0] in2;
    reg en = 1'b1;
//    (* dont_touch = "yes" *)reg [31:0] shift_pipe3;
//    reg [2*base_mult:0] mult_pipe; 
    (* use_dsp = "yes" *)wire [2*base_mult:0] mult_result;
    reg [2*bram_depth-2:0] map;
    reg [2*base_mult + $clog2(bram_depth):0] mult_rr, mid;
    wire [2*base_mult + $clog2(bram_depth):0] mid_x;

    reg ena = 1'b1;
    reg wea = 1'b0;
    wire [2*bram_depth-2:0] addrouta;
    wire [2*bram_depth-2:0] addroutb;

    reg [2*bram_depth-2:0] addrouta1;
    reg [2*bram_depth-2:0] addroutb1;
    reg [2*bram_depth-2:0] addrouta2;
    reg [2*bram_depth-2:0] addroutb2;
    
    reg [2*base_mult + $clog2(bram_depth):0] dinouta;
    reg [2*base_mult + $clog2(bram_depth):0] dinoutb;
    wire [2*base_mult + $clog2(bram_depth):0] dinoutb_dup;
    wire [2*base_mult + $clog2(bram_depth):0] doutouta;
    wire [2*base_mult + $clog2(bram_depth):0] doutoutb;
    
    reg [2*base_mult + $clog2(bram_depth):0] a;
    reg [2*base_mult + $clog2(bram_depth):0] b;
    reg [2*base_mult + $clog2(bram_depth)+1:0] total_sum = 0;
    
    reg enb = 1'b1;
    reg web = 1'b1;

    reg signed [$clog2(base_mult*bram_depth)+1:0] count = 0;
    reg signed [$clog2(base_mult*bram_depth)+1:0] a_idx = 0;
    reg signed [$clog2(base_mult*bram_depth)+1:0] b_idx = 0;
    
    reg accumulation_done = 1'b0;
    reg signed [$clog2(base_mult*bram_depth)+1:0] idx_a_port = 0;
    reg signed [$clog2(base_mult*bram_depth)+1:0] idx_b_port = 0;
    reg [$clog2(base_mult*bram_depth)+1:0] c = 0;
            
    generate
        if (num_clocks == 1) begin: base_case
            generic_base_multiplier #(base_mult) dut(.clk(clk), .x1(douta0), .y1(doutb0), .x2(douta1), .y2(doutb1), .a_in(a_in), .b_in(b_in), .out(mult_result), .en(en), .x(in1), .y(in2));
            a a1 (
            .clka(clk),    // input wire clka
            .ena(ena2), 
            .wea(wein),      // input wire [0 : 0] wea
            .addra(addra0),  // input wire [15 : 0] addra
            .dina(dina0),    // input wire [31 : 0] dina
            .douta(douta0)  // output wire [31 : 0] douta
            );
            a a2 (
            .clka(clk),    // input wire clka
            .ena(ena1), 
            .wea(wein),      // input wire [0 : 0] wea
            .addra(addra1),  // input wire [15 : 0] addra
            .dina(dina1),    // input wire [31 : 0] dina
            .douta(douta1)  // output wire [31 : 0] douta
            );
            a b1 (
            .clka(clk),    // input wire clka
            .ena(ena2), 
            .wea(wein),      // input wire [0 : 0] wea
            .addra(addrb0),  // input wire [15 : 0] addra
            .dina(dinb0),    // input wire [31 : 0] dina
            .douta(doutb0)  // output wire [31 : 0] douta
            );
            a b2 (
            .clka(clk),    // input wire clka
            .ena(ena1), 
            .wea(wein),      // input wire [0 : 0] wea
            .addra(addrb1),  // input wire [15 : 0] addra
            .dina(dinb1),    // input wire [31 : 0] dina
            .douta(doutb1)  // output wire [31 : 0] douta
            );

            // reg [2*bram_depth-2:0] carry = 0;

            
            assign addrouta = (accumulation_done == 1'b1)? addrouta2:addrouta1;
            assign addroutb = (accumulation_done == 1'b1)? addroutb2:addroutb1;
            assign addra0 = (wein == 1'b1)?addra00:addra01;
            assign addra1 = (wein == 1'b1)?addra10:addra11;
            assign addrb0 = (wein == 1'b1)?addrb00:addrb01;
            assign addrb1 = (wein == 1'b1)?addrb10:addrb11;
            assign dinoutb_dup = dinoutb;
            assign mid_x = mid;
            outp final_out (
            .clka(clk),    // input wire clka
            .ena(ena),      // input wire ena
            .wea(wea),      // input wire [0 : 0] wea
            .addra(addrouta),  // input wire [1 : 0] addra
            .dina(dinouta),    // input wire [127 : 0] dina
            .douta(doutouta),  // output wire [127 : 0] douta
            .clkb(clk),    // input wire clkb
            .enb(enb),      // input wire enb
            .web(web),      // input wire [0 : 0] web
            .addrb(addroutb),  // input wire [1 : 0] addrb
            .dinb(dinoutb_dup),    // input wire [127 : 0] dinb
            .doutb(doutoutb)  // output wire [127 : 0] doutb
            );

            always @(posedge clk) begin
                prev_size <= size;
            end
            
//            reg [$clog2(interface_bits*bram_depth)+1:0] c = 0;
            
            always @(posedge clk) begin
                if (reset == 1'b0 && wein == 1'b1) begin
                    if(c == 0 && num_blocks == 1)begin
                        addra00 <= c;
                        dina0 <= x;
                        addra10 <= c;
                        dina1 <= 0;
                        
                        addrb00 <= c;
                        dinb0 <= y;
                        addrb10 <= c;
                        dinb1 <= 0;
                        
                        c <= c + 1;
                        wein <= 1'b1;
                        en <= 1'b1;
                    end
                    if(c <= num_blocks-1 && num_blocks != 1) begin
                        if(c % 2 == 0)begin
                            addra00 <= c / 2;
                            dina0 <= x;
                            addrb00 <= c / 2;
                            dinb0 <= y;
                        end
                        else begin
                            addra10 <= c / 2;
                            dina1 <= x;
                            addrb10 <= c / 2;
                            dinb1 <= y;
                        end
                        c <= c + 1;
                        wein <= 1'b1;
                        en <= 1'b1;
                    end
                    else begin
                        wein <= 1'b0;
                        en <= 1'b0;
                        c <= c + 1;
                    end
                end
                else if (wein == 1'b0 && reset != 1'b1)begin
                    c <= c + 1;
                end
                else if(reset == 1'b1) begin
                    c <= 0;
                    wein <= 1'b1;
                    en <= 1'b1;
                    addra00 <= 0;
                    addra10 <= 0;
                    addrb00 <= 0;
                    addrb10 <= 0;
                end
            end
            always@(posedge clk)begin
                if((prev_size == size || c == 0) && (c < num_blocks) && (reset == 1'b0) && (wein == 1'b1))begin
                    if(c == 0)begin
                        in1 <= x;
                        in2 <= y;
                    end
                    else begin
                        in1 <= x;
                        in2 <= in2;
                    end
                end
                else begin
                    in1 <= 0;
                    in2 <= 0;
                end
                if ((prev_size == size || count == 0) && (wein == 1'b0 && reset == 1'b0)) begin
                // $display("%b", size);
                    if(a_idx == 0) begin
                        addra01 <= 32'b0;
                        a_idx <= a_idx + 1;
                    end
                    else if (a_idx == 1) begin
                        addra11 <= 32'b0;
                        a_idx <= a_idx + 1;
                    end
                    else if ((a_idx < num_blocks-1) && (a_idx > 1)) begin
                        if (a_idx % 2 == 0) begin
                            addra01 <= addra01 + 1;
                        end
                        else if (a_idx % 2 == 1) begin
                            addra11 <= addra11 + 1;
                        end
                        a_idx <= a_idx + 1;
                    end
                    else if ((a_idx == num_blocks-1) && (a_idx > 1)) begin
                        addra11 <= addra11 + 1;
                        a_idx <= 0;
                    end
            
                    if (b_idx == 2) begin
                        addrb01 <= 32'b000001;
                        b_idx <= b_idx + 1;
                    end 
                    else if (b_idx == 1 && ((a_idx == num_blocks-2) || (num_blocks-2 <= 0))) begin
                        addrb11 <= 32'b0;
                        b_idx <= b_idx + 1;
                    end
                    else if ((b_idx < num_blocks) && (a_idx == num_blocks-2) && (b_idx > 1)) begin
                        if (b_idx % 2 == 0) begin
                            addrb01 <= addrb01 + 1;
                        end
                        else if (b_idx % 2 == 1) begin
                            addrb11 <= addrb11 + 1;
                        end
                        b_idx <= b_idx + 1;
                    end
                    count <= count + 1;
        //            en <= 0;
                end
                else if(reset == 1'b1)begin
                    count <= 0;
                    a_idx <= 0;
                    b_idx <= 1;
                    addra01 <= 0;
                    addra11 <= 0;
                    addrb01 <= 0;
                    addrb11 <= 0;
                end
                // $display("count %b", count);
            end

            always @(posedge clk) begin
                // if((prev_size == size || c == 2) && (c < num_blocks + 2) && (reset == 1'b0))begin
                //     mult_pipe <= mult_result;
                //     shift_pipe2 <= c - 2;
                // end
                // else begin
                //     shift_pipe2 <= 0;
                //     mult_pipe <= 0;
                // end
                if((prev_size == size || count == 0) && (wein == 1'b0)) begin
                    if(count < 2) begin
                        addrouta1 <= 0;
                        p_a_idx <= 0;
                        p_b_idx <= 1;
                    end
                    else if (count >= 2) begin
                        if ((p_a_idx <= num_blocks-1) && (p_b_idx <= num_blocks-1)) begin
                            a_in = (p_a_idx % 2 == 0)? 1'b0:1'b1;
                            b_in = (p_b_idx % 2 == 0)? 1'b0:1'b1;
                            // $display("douta[0] %d, doutb[0] %d douta[1] %d doutb[1] %d a_in %d b_in %d", douta[0], doutb[0], douta[1], doutb[1], a_in, b_in);
                            shift_pipe1 <= (p_a_idx + p_b_idx);
                            addrouta1 <= (p_a_idx + p_b_idx);
                            if (p_a_idx == num_blocks-1) begin
                                p_a_idx <= 0;
                                p_b_idx <= p_b_idx + 1;
                            end
                            else if (p_a_idx < num_blocks-1) begin
                                p_a_idx <= p_a_idx + 1;
                                p_b_idx <= p_b_idx;
                            end
                        end
                    end
                end
                else if(reset == 1'b1)begin
                    p_a_idx <= 0;
                    p_b_idx <= 0;
                    addrouta1 <= 7;
                    a_in = 0;
                    b_in = 0;
                end
            end

            always @(posedge clk) begin
                if ((prev_size == size || count == 0) && (wein == 1'b0)) begin
                    shift_pipe2 <= shift_pipe1;
                end
                else begin
                    shift_pipe2 <= 0;
                end
            end
            
            always @(posedge clk) begin
                if(prev_size == size && (c >= 2) && (c < num_blocks + 2))begin
                    if(c == 3 && num_blocks == 2) begin
                        mid <= mult_result;
                    end
                    else begin
                        web <= 1'b1;
                        addroutb1 <= c - 2;
                        dinoutb <= mult_result;
                        map[addroutb1] = 1'b1;
                    end
                    accumulation_done <= 1'b0;
                end
//                else if(prev_size == size && c == 3 && num_blocks == 2)begin
//                    web <= 1'b1;
//                    mid <= mult_result;
//                    accumulation_done <= 1'b0;
//                end 
                else if (prev_size == size && (wein == 1'b0)) begin
                    if (count >= 4 && count - 4 < (num_blocks*num_blocks - num_blocks))begin
                        mult_rr = {1'b0, mult_result};
                        if(num_blocks == 2 && shift_pipe2 == 1)begin
                            mid <= mult_rr + mid;
                        end
                        // $display("mult_pipe2 %d, doutouta %d, shift_pipe3 %d", mult_pipe2, doutouta, shift_pipe3);
                        else begin
                            web <= 1'b1;
                            addroutb1 <= shift_pipe2;
                            dinoutb <= (map[shift_pipe2] == 1'b1) ? (doutouta + mult_rr): mult_rr;
                            map[addroutb1] = 1'b1;
                        end
                        accumulation_done <= 1'b0;
                        // $display("dinoutb %d", dinoutb);
                    end
                    else if (count - 4 >= num_blocks*num_blocks-num_blocks) begin
                        // $display("%b, %b", count-4, num_blocks*num_blocks);
                        accumulation_done <= 1'b1;
                        web <= 1'b0;
                    end
                    else if (count < 3 && c >= num_blocks + 2) begin
                        web <= 1'b0;
                    end
                    else begin
                        web <= 1'b1;
                    end
                end
                else if(reset == 1'b1)begin
                    addroutb1 <= 1;
                    dinoutb <= 0;
                    web <= 1'b1;
                    map = 0;
                    mult_rr = 0;
                    mid <= 0;
                    accumulation_done <= 0;
                end
            end

            always @(posedge clk) begin
                if(prev_size == size && (wein == 1'b0))begin
                // $display("numblocks %b, idx_a_port %b", num_blocks*num_blocks, idx_a_port);
                    if (accumulation_done == 1'b0)begin
                        addrouta2 <= 0;
                        addroutb2 <= 0;
                        idx_a_port <= 0;
                        idx_b_port <= 0;
        //                map[shift_pipe2] <= 1'b1;
                    end
                    else if(accumulation_done == 1'b1 && idx_a_port <= 2*num_blocks-2) begin
                        addrouta2 <= idx_a_port;
                        if (idx_a_port != 0 && idx_b_port <= 2*num_blocks-2) begin
                            addroutb2 <= idx_b_port + 1;
                            idx_b_port <= idx_b_port + 1;
                        end
                        idx_a_port <= idx_a_port + 1;
                    end
                    else if (accumulation_done == 1'b1 && idx_a_port <= 2*num_blocks+1 && idx_a_port > 2*num_blocks-2) begin
                        idx_a_port <= idx_a_port + 1;
                        idx_b_port <= idx_b_port + 1;
                    end
                end
                else if(reset == 1'b1)begin
                    addrouta2 <= 0;
                    addroutb2 <= 0;
                    idx_a_port <= 0;
                    idx_b_port <= 0;
        //            map <= 0;
                end
            end

            always @(posedge clk) begin
                if(prev_size == size && (wein == 1'b0))begin
                    // $display("idx_a_port %b, %b", idx_a_port, num_blocks);
                    if(idx_a_port >= 1 && idx_a_port <= 2*num_blocks+1) begin
                        a <= doutouta;
                        // $display("idx_a_port %b, %b", idx_a_port, 2*num_blocks+1);
                        if (idx_a_port == 2) begin
                            // $display("going 1");
                            outf <= a[base_mult-1:0];
                            total_sum = 0;
        //                    done <= 1'b0;
//                            start = 1'b1;
                        end
                        else if (idx_a_port == 2*num_blocks+1) begin
                            // $display("idx_a_port %b, %b", idx_a_port, 2*num_blocks+1);
                            // $display("going 2");
//                            start = 1'b1;
                            outf <= total_sum[2*base_mult-1:base_mult];
                            carry <= total_sum[2*base_mult + $clog2(bram_depth):2*base_mult];
        //                    done <= 1'b1;
                        end
                        else if((idx_a_port != 2) && (idx_b_port == 2)) begin
                            // $display("going 3");
                            b = doutoutb;
                            // $display("%d", b);
//                            start = 1'b1;
                            total_sum = (num_blocks == 2)? (mid_x + {1'b0, a[2*base_mult + $clog2(bram_depth):base_mult]}): (b + {1'b0, a[2*base_mult + $clog2(bram_depth):base_mult]});
                            outf <= total_sum[base_mult-1:0];
        //                    done <= 1'b0;
                        end
                        else if ((idx_a_port != 2) && (idx_b_port > 2) && (idx_b_port <= 2*num_blocks)) begin
                            // $display("going 4");
                            b = doutoutb;
//                            start = 1'b1;
                            total_sum = b + {1'b0, total_sum[2*base_mult + $clog2(bram_depth):base_mult]};
                            outf <= total_sum[base_mult-1:0];
        //                    done <= 1'b0;
                        end
                    end
                end
                else if(reset == 1'b1)begin
                    outf <= 0;
                    carry <= 0;
                    a = 0;
                    b = 0;
                    total_sum = 0;
//                    start <= 1'b0;
        //            done <= 1'b0;
                end
            end

        assign out = outf;
        end else begin: parameterised
            generic_base_multiplier #(base_mult) dut(.clk(clk), .x1(douta0), .y1(doutb0), .x2(douta1), .y2(doutb1), .a_in(a_in), .b_in(b_in), .out(mult_result), .en(en), .x(in1), .y(in2));
            wire startf;
            wire [2*bram_depth-2:0] addrmain;
            reg [31:0] n_count = 0;
            reg [2*bram_depth-2:0] addr, addr1;
            reg [base_mult-1:0] din;
            wire [base_mult-1:0] dout;
            reg [interface_bits-1:0] outb;
        
            reg ctrl;
            a a1 (
            .clka(clk),    // input wire clka
            .ena(ena2), 
            .wea(wein),      // input wire [0 : 0] wea
            .addra(addra0),  // input wire [15 : 0] addra
            .dina(dina0),    // input wire [31 : 0] dina
            .douta(douta0)  // output wire [31 : 0] douta
            );
            a a2 (
            .clka(clk),    // input wire clka
            .ena(ena1), 
            .wea(wein),      // input wire [0 : 0] wea
            .addra(addra1),  // input wire [15 : 0] addra
            .dina(dina1),    // input wire [31 : 0] dina
            .douta(douta1)  // output wire [31 : 0] douta
            );
            a b1 (
            .clka(clk),    // input wire clka
            .ena(ena2), 
            .wea(wein),      // input wire [0 : 0] wea
            .addra(addrb0),  // input wire [15 : 0] addra
            .dina(dinb0),    // input wire [31 : 0] dina
            .douta(doutb0)  // output wire [31 : 0] douta
            );
            a b2 (
            .clka(clk),    // input wire clka
            .ena(ena1), 
            .wea(wein),      // input wire [0 : 0] wea
            .addra(addrb1),  // input wire [15 : 0] addra
            .dina(dinb1),    // input wire [31 : 0] dina
            .douta(doutb1)  // output wire [31 : 0] douta
            );
            
            a_out1 a_out(
              .clka(clk),    // input wire clka
              .ena(1'b1),      // input wire ena
              .wea(startf),      // input wire [0 : 0] wea
              .addra(addrmain),  // input wire [3 : 0] addra
              .dina(din),    // input wire [15 : 0] dina
              .douta(dout)  // output wire [15 : 0] douta
            );
            reg [base_mult-1:0] x_cat = 0;
            reg [base_mult-1:0] y_cat = 0;
            reg [31:0] num_count = 0;
            
            assign addrouta = (accumulation_done == 1'b1)? addrouta2:addrouta1;
            assign addroutb = (accumulation_done == 1'b1)? addroutb2:addroutb1;
            assign addra0 = (wein == 1'b1)?addra00:addra01;
            assign addra1 = (wein == 1'b1)?addra10:addra11;
            assign addrb0 = (wein == 1'b1)?addrb00:addrb01;
            assign addrb1 = (wein == 1'b1)?addrb10:addrb11;
            assign startf = (ctrl == 1'b1)?((idx_a_port >= 2)?1'b1:1'b0):1'b0;
            assign addrmain = (ctrl == 1'b1)?addr:addr1;
    
            outp final_out (
            .clka(clk),    // input wire clka
            .ena(ena),      // input wire ena
            .wea(wea),      // input wire [0 : 0] wea
            .addra(addrouta),  // input wire [1 : 0] addra
            .dina(dinouta),    // input wire [127 : 0] dina
            .douta(doutouta),  // output wire [127 : 0] douta
            .clkb(clk),    // input wire clkb
            .enb(enb),      // input wire enb
            .web(web),      // input wire [0 : 0] web
            .addrb(addroutb),  // input wire [1 : 0] addrb
            .dinb(dinoutb_dup),    // input wire [127 : 0] dinb
            .doutb(doutoutb)  // output wire [127 : 0] doutb
            );
            assign dinoutb_dup = dinoutb;
            always @(posedge clk) begin
                prev_size <= size;
            end
            
            reg [$clog2(base_mult*bram_depth)+1:0] c_x, c_y = 0;
            always @(posedge clk) begin
                if(reset == 1'b1 && prev_size == size) begin
        //            enable <= 1'b1;
                    x_cat <= 0;
                    y_cat <= 0;
                    num_count = 0;
                end
                else if (num_count < num_clocks && num_count > 0 && prev_size == size) begin
                    x_cat <= (x << (num_count)*interface_bits) | x_cat;
                    y_cat <= (y << (num_count)*interface_bits) | y_cat;
                    num_count = num_count + 1;
                end
                else if (num_count == num_clocks && prev_size == size) begin
                    x_cat <= {base_mult{1'b0}} | x;
                    y_cat <= {base_mult{1'b0}} | x;
                    num_count = 1;
                end
                else if (num_count == 0 && prev_size == size) begin
                    x_cat <= x;
                    y_cat <= y;
                    num_count = num_count + 1;
                end
            end
            always @(posedge clk) begin
                if (reset == 1'b0 && wein == 1'b1) begin
                    if(c == 0 && num_blocks == 1)begin
                        addra00 <= c;
                        dina0 <= x_cat;
                        addra10 <= c;
                        dina1 <= 0;
                        
                        addrb00 <= c;
                        dinb0 <= y_cat;
                        addrb10 <= c;
                        dinb1 <= 0;
                        
                        c <= c + 1;
                        wein <= 1'b1;
                        en <= 1'b1;
                    end
                    if(num_count == num_clocks && c <= num_blocks-1 && num_blocks != 1) begin
                        if(c % 2 == 0)begin
                            addra00 <= c / 2;
                            dina0 <= x_cat;
                            addrb00 <= c / 2;
                            dinb0 <= y_cat;
                        end
                        else begin
                            addra10 <= c / 2;
                            dina1 <= x_cat;
                            addrb10 <= c / 2;
                            dinb1 <= y_cat;
                        end
                        c <= c + 1;
                        wein <= 1'b1;
                        en <= 1'b1;
                    end
                    else if (c > num_blocks -1)begin
                        wein <= 1'b0;
                        en <= 1'b0;
                        c <= c;
                    end
                end
                else if(reset == 1'b1) begin
                    c <= 0;
                    wein <= 1'b1;
                    en <= 1'b1;
                    addra00 <= 0;
                    addra10 <= 0;
                    addrb00 <= 0;
                    addrb10 <= 0;
                end
            end
            always@(posedge clk)begin
                if((prev_size == size || c_x == 0) && (c_x < num_blocks) && (reset == 1'b0) && (wein == 1'b1))begin
                    if(c_x == 0 && num_count == num_clocks)begin
                        in1 <= x_cat;
                        in2 <= y_cat;
                        c_x <= c_x + 1;
                    end
                    else if (num_count == num_clocks)begin
                        in1 <= x_cat;
                        in2 <= in2;
                        c_x <= c_x + 1;
                    end
                end
                else if(reset == 1'b1 && wein == 1'b1)begin
                    in1 <= 0;
                    in2 <= 0;
                    c_x <= 0;
                end
                if ((prev_size == size || count == 0) && (wein == 1'b0 && reset == 1'b0)) begin
                // $display("%b", size);
                    if(a_idx == 0) begin
                        addra01 <= 32'b0;
                        a_idx <= a_idx + 1;
                    end
                    else if (a_idx == 1) begin
                        addra11 <= 32'b0;
                        a_idx <= a_idx + 1;
                    end
                    else if ((a_idx < num_blocks-1) && (a_idx > 1)) begin
                        if (a_idx % 2 == 0) begin
                            addra01 <= addra01 + 1;
                        end
                        else if (a_idx % 2 == 1) begin
                            addra11 <= addra11 + 1;
                        end
                        a_idx <= a_idx + 1;
                    end
                    else if ((a_idx == num_blocks-1) && (a_idx > 1)) begin
                        addra11 <= addra11 + 1;
                        a_idx <= 0;
                    end
            
                    if (b_idx == 2) begin
                        addrb01 <= 32'b000001;
                        b_idx <= b_idx + 1;
                    end 
                    else if (b_idx == 1 && ((a_idx == num_blocks-2) || (num_blocks-2 <= 0))) begin
                        addrb11 <= 32'b0;
                        b_idx <= b_idx + 1;
                    end
                    else if ((b_idx < num_blocks) && (a_idx == num_blocks-2) && (b_idx > 1)) begin
                        if (b_idx % 2 == 0) begin
                            addrb01 <= addrb01 + 1;
                        end
                        else if (b_idx % 2 == 1) begin
                            addrb11 <= addrb11 + 1;
                        end
                        b_idx <= b_idx + 1;
                    end
                    count <= count + 1;
        //            en <= 0;
                end
                else if(reset == 1'b1)begin
                    count <= 0;
                    a_idx <= 0;
                    b_idx <= 1;
                    addra01 <= 0;
                    addra11 <= 0;
                    addrb01 <= 0;
                    addrb11 <= 0;
                end
                // $display("count %b", count);
            end

            always @(posedge clk) begin
                // if((prev_size == size || c == 2) && (c < num_blocks + 2) && (reset == 1'b0))begin
                //     mult_pipe <= mult_result;
                //     shift_pipe2 <= c - 2;
                // end
                // else begin
                //     shift_pipe2 <= 0;
                //     mult_pipe <= 0;
                // end
                if((prev_size == size || count == 0) && (wein == 1'b0)) begin
                    if(count < 2) begin
                        addrouta1 <= 0;
                        p_a_idx <= 0;
                        p_b_idx <= 1;
                    end
                    else if (count >= 2) begin
                        if ((p_a_idx <= num_blocks-1) && (p_b_idx <= num_blocks-1)) begin
                            a_in = (p_a_idx % 2 == 0)? 1'b0:1'b1;
                            b_in = (p_b_idx % 2 == 0)? 1'b0:1'b1;
                            // $display("douta[0] %d, doutb[0] %d douta[1] %d doutb[1] %d a_in %d b_in %d", douta[0], doutb[0], douta[1], doutb[1], a_in, b_in);
                            shift_pipe1 <= (p_a_idx + p_b_idx);
                            addrouta1 <= (p_a_idx + p_b_idx);
                            if (p_a_idx == num_blocks-1) begin
                                p_a_idx <= 0;
                                p_b_idx <= p_b_idx + 1;
                            end
                            else if (p_a_idx < num_blocks-1) begin
                                p_a_idx <= p_a_idx + 1;
                                p_b_idx <= p_b_idx;
                            end
                        end
                    end
                end
                else if(reset == 1'b1)begin
                    p_a_idx <= 0;
                    p_b_idx <= 0;
                    addrouta1 <= 7;
                    a_in = 0;
                    b_in = 0;
                end
            end

            always @(posedge clk) begin
                if ((prev_size == size || count == 0) && (wein == 1'b0)) begin
                    shift_pipe2 <= shift_pipe1;
        //            shift_pipe3 <= shift_pipe1;
        //            mult_pipe <= mult_result;
                end
                else begin
                    shift_pipe2 <= 0;
        //            shift_pipe3 <= 0;
        //            mult_pipe <= 0;
                end
            end
            always @(posedge clk) begin
                if(prev_size == size && c_y <= num_blocks-1 && c_x != 0)begin
                    if((num_count == 2) && num_blocks == 2 && c_y == 1) begin
                        mid <= mult_result;
                        c_y = c_y + 1;
                    end
                    else if((num_count == 2))begin
        //                web <= 1'b1;
                        addroutb1 <= c_y;
                        dinoutb <= mult_result;
                        map[addroutb1] = 1'b1;
                        c_y = c_y + 1;
                    end
                    web <= 1'b1;
                    accumulation_done <= 1'b0;
                end
                else if (prev_size == size && (wein == 1'b0)) begin
                    if (count >= 4 && count - 4 < (num_blocks*num_blocks - num_blocks))begin
                        mult_rr = {1'b0, mult_result};
                        if(num_blocks == 2 && shift_pipe2 == 1)begin
                            mid <= mult_rr + mid;
                        end
                        // $display("mult_pipe2 %d, doutouta %d, shift_pipe3 %d", mult_pipe2, doutouta, shift_pipe3);
                        else begin
                            web <= 1'b1;
                            addroutb1 <= shift_pipe2;
                            dinoutb <= (map[shift_pipe2] == 1'b1) ? (doutouta + mult_rr): mult_rr;
                            map[addroutb1] = 1'b1;
                        end
                        accumulation_done <= 1'b0;
                        // $display("dinoutb %d", dinoutb);
                    end
                    else if (count - 4 >= num_blocks*num_blocks-num_blocks) begin
                        // $display("%b, %b", count-4, num_blocks*num_blocks);
                        accumulation_done <= 1'b1;
                        web <= 1'b0;
                    end
                    else if (count < 3 && c >= num_blocks + 2) begin
                        web <= 1'b0;
                    end
                    else begin
                        web <= 1'b1;
                    end
                end
                else if (reset == 1'b1)begin
                    addroutb1 <= 1;
                    dinoutb <= 0;
                    web <= 1'b1;
                    map = 0;
                    mult_rr = 0;
                    mid <= 0;
                    accumulation_done <= 0;
                    c_y = 0;
                end
            end

            always @(posedge clk) begin
                if(prev_size == size && (wein == 1'b0))begin
                // $display("numblocks %b, idx_a_port %b", num_blocks*num_blocks, idx_a_port);
                    if (accumulation_done == 1'b0)begin
                        addrouta2 <= 0;
                        addroutb2 <= 0;
                        idx_a_port <= 0;
                        idx_b_port <= 0;
        //                map[shift_pipe2] <= 1'b1;
                    end
                    else if(accumulation_done == 1'b1 && idx_a_port <= 2*num_blocks-2) begin
                        addrouta2 <= idx_a_port;
                        if (idx_a_port != 0 && idx_b_port <= 2*num_blocks-2) begin
                            addroutb2 <= idx_b_port + 1;
                            idx_b_port <= idx_b_port + 1;
                        end
                        idx_a_port <= idx_a_port + 1;
                    end
                    else if (accumulation_done == 1'b1 && idx_a_port <= 2*num_blocks+1 && idx_a_port > 2*num_blocks-2) begin
                        idx_a_port <= idx_a_port + 1;
                        idx_b_port <= idx_b_port + 1;
                    end
                end
                else if(reset == 1'b1)begin
                    addrouta2 <= 0;
                    addroutb2 <= 0;
                    idx_a_port <= 0;
                    idx_b_port <= 0;
        //            map <= 0;
                end
            end

            always @(posedge clk) begin
                if(prev_size == size && (wein == 1'b0))begin
                    // $display("idx_a_port %b, %b", idx_a_port, num_blocks);
                    if(idx_a_port >= 1 && idx_a_port <= 2*num_blocks+1) begin
                        a <= doutouta;
                        // $display("idx_a_port %b, %b", idx_a_port, 2*num_blocks+1);
                        if (idx_a_port == 2) begin
                            // $display("going 1");
                            outf <= a[base_mult-1:0];
                            total_sum = 0;
//                            done <= 1'b0;
//                            start = 1'b1;
                        end
                        else if (idx_a_port == 2*num_blocks+1) begin
                            // $display("idx_a_port %b, %b", idx_a_port, 2*num_blocks+1);
                            // $display("going 2");
//                            start = 1'b1;
                            outf <= total_sum[2*base_mult-1:base_mult];
                            carry <= total_sum[2*base_mult + $clog2(bram_depth):2*base_mult];
//                            done <= 1'b1;
                        end
                        else if((idx_a_port != 2) && (idx_b_port == 2)) begin
                            // $display("going 3");
                            b = doutoutb;
                            // $display("%d", b);
//                            start = 1'b1;
                            total_sum = (num_blocks == 2)? (mid + {1'b0, a[2*base_mult + $clog2(bram_depth):base_mult]}): (b + {1'b0, a[2*base_mult + $clog2(bram_depth):base_mult]});
                            outf <= total_sum[base_mult-1:0];
//                            done <= 1'b0;
                        end
                        else if ((idx_a_port != 2) && (idx_b_port > 2) && (idx_b_port <= 2*num_blocks)) begin
                            // $display("going 4");
                            b = doutoutb;
//                            start = 1'b1;
                            total_sum = b + {1'b0, total_sum[2*base_mult + $clog2(bram_depth):base_mult]};
                            outf <= total_sum[base_mult-1:0];
//                            done <= 1'b0;
                        end
                    end
                end
                else if(reset == 1'b1)begin
                    outf <= 0;
                    carry <= 0;
                    a = 0;
                    b = 0;
                    total_sum = 0;
//                    start <= 1'b0;
//                    done <= 1'b0;
                end
            end
            
        assign out = outb;
        
//        reg ctrl;
        
        always @(posedge clk) begin
                if(idx_a_port >= 2 && addr >= 0) begin
                    if(idx_a_port == 2) begin
                        addr <= 0;
                    end
                    else if(addr <= 2*num_blocks-1) begin
//                        bp = bp + 1;
                        addr <= addr+1;
                        din <= outf;
                        ctrl <= 1'b1;
                    end
                    else if(addr == 2*num_blocks) begin 
                        ctrl <= 1'b0;
                    end
                end
                else if (idx_a_port < 2) begin
//                    bp = 0;
                    addr <= 0;
                    din <= 0;
                    ctrl <= 1'b1;
                end
            end
            
            always @(posedge clk) begin
                if(idx_a_port >= 2 && ctrl == 1'b1) begin
                    addr1 <= 0;
                    n_count <= 1;
                end
                else if (idx_a_port >= 2 && ctrl == 1'b0) begin
                    if(n_count == num_clocks) begin
                        addr1 <= addr1 + 1;
                        n_count <= n_count + 1;
                    end
                    else if(n_count == num_clocks+1) begin
                        n_count <= 2;
                    end
                    else begin
                        n_count <= n_count + 1;
                        addr1 <= addr1;
                    end
                end
            end
            
            always @(posedge clk) begin
                if(reset == 1'b1) begin
                    outb <= 0;
//                    start_stream <= 0;
        //            done_stream = 0;
//                    temp_mult = 0;
                end
                if(n_count > 1 && addr1 >= 0 && reset == 1'b0 && ctrl == 1'b0) begin
                    outb <= dout[(n_count-2)*interface_bits +: interface_bits];
//                    start_stream <= 1;
        //            done_stream = (addr1 > 2*num_clocks-1)?1:0;
                end
                else if (num_clocks == 1 && reset == 1'b0) begin
                    if(num_blocks != 1 && ctrl == 1'b0) begin
                    outb <= dout;
//                    start_stream <= 1;
        //            done_stream = (addr1 > 2*num_clocks-1)?1:0;
                    end
                end
                else begin
                    outb <= 0;
        //            done_stream = 0;
//                    temp_mult = 0;
                end
            end
        end
    endgenerate
endmodule
