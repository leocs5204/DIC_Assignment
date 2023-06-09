module demosaic(clk, reset, in_en, data_in, wr_r, addr_r, wdata_r, rdata_r, wr_g, addr_g, wdata_g, rdata_g, wr_b, addr_b, wdata_b, rdata_b, done);
input clk;
input reset;
input in_en;
input [7:0] data_in;
output reg wr_r;
output reg [13:0] addr_r;
output reg [7:0] wdata_r;
input [7:0] rdata_r;
output reg wr_g;
output reg [13:0] addr_g;
output reg [7:0] wdata_g;
input [7:0] rdata_g;
output reg wr_b;
output reg [13:0] addr_b;
output reg [7:0] wdata_b;
input [7:0] rdata_b;
output reg done;

parameter WIDTH = 128;
parameter HEIGHT = 128;

reg       line_buf1_ready, line_buf2_ready, line_buf3_ready;
reg [7:0] line_buf1 [0 : WIDTH-1], line_buf2 [0 : WIDTH-1], line_buf3 [0 : WIDTH-1];            // declare line buffer 
reg [6:0] pixel_col, col_idx, row_idx;
reg signed [8:0] shift_reg[0:14];                          // Define shift registers
reg [13:0] wr_addr;
reg signed [11:0] KB_l, KB_r, KB_t, KB_b, KR_l, KR_r, KR_t, KR_b;
reg signed [11:0] KBG_l, KBG_r, KBG_t, KBG_b, KRG_l, KRG_r, KRG_t, KRG_b;
reg signed [11:0] GH, GV;
reg        [7:0] delta_V, delta_H;
reg       weight_sel;
reg signed [15:0] g_hat, r_hat, b_hat;
wire shift_reg_ready;

integer i ;

assign shift_reg_ready = ((line_buf3_ready && pixel_col == 0) || (line_buf2_ready && pixel_col > 4));


always@(posedge clk or posedge reset) begin
    if(reset) begin
        pixel_col <= 0;
    end
    else begin
        if(pixel_col < (WIDTH-1))
            pixel_col <= pixel_col + 1;
        else
            pixel_col <= 0;
    end
end


always@(posedge clk or posedge reset) begin
    if(reset) begin
        line_buf1_ready <= 0;
        line_buf2_ready <= 0;
        line_buf3_ready <= 0;
        for(i=0; i<WIDTH; i=i+1) begin
            line_buf1[i] <= 0;
            line_buf2[i] <= 0;
            line_buf3[i] <= 0;
        end
    end    
    else if(in_en) begin
        if(!line_buf1_ready) begin
            line_buf1[pixel_col] <= data_in;
            if(pixel_col == 127)
                line_buf1_ready <= 1;
        end
        else if(!line_buf2_ready) begin
            line_buf2[pixel_col] <= data_in;
            if(pixel_col == 127)
                line_buf2_ready <= 1;
        end
        else begin
            if(pixel_col==127)
                line_buf3_ready <= 1;

            if(line_buf3_ready && (pixel_col == 0)) begin
                for(i=0; i<WIDTH; i=i+1) begin
                    line_buf1[i] <= line_buf2[i];
                    line_buf2[i] <= line_buf3[i];
                end
            end
            line_buf3[pixel_col] <= data_in;
            
        end
    end
end

// assign shift registers
always@(*) begin
    if(reset) begin
        for(i=0; i<15; i=i+1)
            shift_reg[i] <= 8'd0;
    end
    else begin 
        shift_reg[0] <= line_buf1[col_idx-2];
        shift_reg[1] <= line_buf2[col_idx-2];
        shift_reg[2] <= line_buf3[col_idx-2];
        shift_reg[3] <= line_buf1[col_idx-1];
        shift_reg[4] <= line_buf2[col_idx-1];
        shift_reg[5] <= line_buf3[col_idx-1];
        shift_reg[6] <= line_buf1[col_idx];
        shift_reg[7] <= line_buf2[col_idx];
        shift_reg[8] <= line_buf3[col_idx];
        shift_reg[9] <= line_buf1[col_idx+1];
        shift_reg[10] <= line_buf2[col_idx+1];
        shift_reg[11] <= line_buf3[col_idx+1];
        shift_reg[12] <= line_buf1[col_idx+2];
        shift_reg[13] <= line_buf2[col_idx+2];
        shift_reg[14] <= line_buf3[col_idx+2];
    end
end


always@(posedge clk or posedge reset) begin
    if(reset) begin
        col_idx <= 2;
        row_idx <= 1;
    end
    else if(shift_reg_ready) begin
        if(col_idx < 125)
            col_idx <= col_idx + 1;
        else begin
            col_idx <= 2;
            if(row_idx < 126)
                row_idx <= row_idx + 1;
            else begin
                row_idx <= 126;
            end
        end
    end
end


// Pre Calculation
always@(*) begin
    case({row_idx[0], col_idx[0]})
        2'b11: begin              // G phase: BGGR
            // interpolate R
            KRG_t = (shift_reg[3] + shift_reg[9]) - (shift_reg[6] <<< 1);
            KRG_b = (shift_reg[5] + shift_reg[11]) - (shift_reg[8] <<< 1);
            // interpolate B
            KBG_l = (shift_reg[1] + shift_reg[3] + shift_reg[5] + shift_reg[7]) - (shift_reg[4] <<< 2);
            KBG_r = (shift_reg[7] + shift_reg[9] + shift_reg[11] + shift_reg[13]) - (shift_reg[10] <<< 2);
        end

        2'b10: begin              // B phase: GBRG
            // interpolation G
            KB_l = (shift_reg[4] <<< 1)- (shift_reg[1] + shift_reg[7]);       //G - (R left + R right)/2
            KB_r = (shift_reg[10] <<< 1) - (shift_reg[7] + shift_reg[13]);
            GH = (shift_reg[7] <<< 1) + (KB_l + KB_r);     
            GV = shift_reg[6] + shift_reg[8];
            delta_V = (shift_reg[6] > shift_reg[8]) ? (shift_reg[6] - shift_reg[8]) : (shift_reg[8] - shift_reg[6]);
            delta_H = (shift_reg[4] > shift_reg[10]) ? (shift_reg[4] - shift_reg[10]) : (shift_reg[10] - shift_reg[4]);
            weight_sel = (delta_V < delta_H);   // 0: Wv = 1/4, Wh = 3/4 | 1: Wv = 3/4, Wh = 1/4 

            // interpolation R
            KR_t = (shift_reg[6] <<< 1) - (shift_reg[3] + shift_reg[9]);
            KR_b = (shift_reg[8] <<< 1) - (shift_reg[5] + shift_reg[11]);
            KR_l = (shift_reg[4] <<< 1) - (shift_reg[3] + shift_reg[5]);
            KR_r = (shift_reg[10] <<< 1) - (shift_reg[9] + shift_reg[11]);
        end
        
        2'b00: begin              // G phase: RGGB
            // interpolate B
            KBG_t = (shift_reg[3] + shift_reg[9]) - (shift_reg[6] <<< 1);
            KBG_b = (shift_reg[5] + shift_reg[11]) - (shift_reg[8] <<< 1);
            // interpolate R
            KRG_l = (shift_reg[1] + shift_reg[3] + shift_reg[5] + shift_reg[7]) - (shift_reg[4] <<< 2);
            KRG_r = (shift_reg[7] + shift_reg[9] + shift_reg[11] + shift_reg[13]) - (shift_reg[10] <<< 2);
        end
        
        2'b01: begin              // R phase: GRBG
            KR_l = (shift_reg[4] <<< 1) - (shift_reg[1] + shift_reg[7]);       //G - (R left + R right)/2
            KR_r = (shift_reg[10] <<< 1) - (shift_reg[7] + shift_reg[13]);
            GH = (shift_reg[7] <<< 1) + (KR_l + KR_r);     
            GV = (shift_reg[6] + shift_reg[8]);
            delta_V = (shift_reg[6] > shift_reg[8]) ? (shift_reg[6] - shift_reg[8]) : (shift_reg[8] - shift_reg[6]);
            delta_H = (shift_reg[4] > shift_reg[10]) ? (shift_reg[4] - shift_reg[10]) : (shift_reg[10] - shift_reg[4]);
            weight_sel = (delta_V < delta_H);   // 0: Wv = 1/4, Wh = 3/4 | 1: Wv = 3/4, Wh = 1/4

            // interpolation B
            KB_t = (shift_reg[6] <<< 1) - (shift_reg[3] + shift_reg[9]);
            KB_b = (shift_reg[8] <<< 1) - (shift_reg[5] + shift_reg[11]);
            KB_l = (shift_reg[4] <<< 1) - (shift_reg[3] + shift_reg[5]);
            KB_r = (shift_reg[10] <<< 1) - (shift_reg[9] + shift_reg[11]);
        end
    endcase
end


// Calculation interpolation result
always@(*) begin
    case({row_idx[0], col_idx[0]})
        2'b11: begin              // G phase: BGGR
            r_hat = (shift_reg[7] << 2) - (KRG_t + KRG_b);      // 4 * r_hat
            g_hat = shift_reg[7];
            b_hat = (shift_reg[7] <<< 3) - (KBG_l + KBG_r);     // 8 * b_hat
        end

        2'b10: begin              // B phase: GBRG
            if(weight_sel)        // 8 * g_hat
                g_hat = ((GV <<< 1) + GV) + GH;     
            else 
                g_hat = GV + ((GH <<< 1) + GH);
            
            r_hat = g_hat - (KR_t + KR_b + KR_l + KR_r);         // 4 * r_hat   
            b_hat = shift_reg[7]; 
        end
        
        2'b00: begin              // G phase: RGGB
            r_hat = (shift_reg[7] <<< 3) - (KRG_l + KRG_r);
            g_hat = shift_reg[7];
            b_hat = (shift_reg[7] <<< 2) - (KBG_t + KBG_l);
        end
        
        2'b01: begin              // B phase: GRBG
            r_hat = shift_reg[7];
            
            if(weight_sel)        // 8 * g_hat
                g_hat = ((GV <<< 1) + GV) + GH;     
            else 
                g_hat = GV + ((GH <<< 1) + GH);
            
            b_hat = g_hat - (KB_t + KB_b + KB_l + KB_r);
        end
    endcase
end

// Address and data write back to memory
always@(posedge clk or posedge reset) begin
    if(reset) begin
        addr_r <= 0;
        addr_g <= 0;
        addr_b <= 0;
        wr_r <= 0;
        wr_g <= 0;
        wr_b <= 0;
        wdata_r <= 0;
        wdata_g <= 0;
        wdata_b <= 0;
    end
    else if(shift_reg_ready) begin
        addr_r <= {row_idx,col_idx};
        addr_g <= {row_idx,col_idx};
        addr_b <= {row_idx,col_idx};
        wr_r <= 1;
        wr_g <= 1;
        wr_b <= 1;

        done <= ({row_idx,col_idx} == 14'd16253);
    end
end


// Deal with rounding 
always@(posedge clk or posedge reset) begin
    if(reset) begin
        wdata_r <= 8'd0;
        wdata_g <= 8'd0;
        wdata_b <= 8'd0;
    end
    else begin
        case({row_idx[0], col_idx[0]})
             2'b11: begin 
                wdata_r <= (r_hat[15]) ? 0 : ((|r_hat[14:10]) ? 255 : (r_hat[9:2] + r_hat[1]));
                wdata_g <= g_hat;
                wdata_b <= (b_hat[15]) ? 0 : ((|b_hat[14:11]) ? 255 : (b_hat[10:3] + b_hat[2]));
             end

             2'b10: begin
                wdata_r <= (r_hat[15]) ? 0 : ((|r_hat[14:11]) ? 255 : (r_hat[10:3] + r_hat[2]));
                wdata_g <= (g_hat[15]) ? 0 : ((|g_hat[14:11]) ? 255 : (g_hat[10:3] + g_hat[2]));
                wdata_b <= b_hat;
             end

             2'b00: begin
                wdata_r <= (r_hat[15]) ? 0 : ((|r_hat[14:11]) ? 255 : (r_hat[10:3] + r_hat[2]));
                wdata_g <= g_hat;
                wdata_b <= (b_hat[15]) ? 0 : ((|b_hat[14:10]) ? 255 : (b_hat[9:2] + b_hat[1]));
             end

             2'b01: begin
                wdata_r <= r_hat;
                wdata_g <= (g_hat[15]) ? 0 : ((|g_hat[14:11]) ? 255 : (g_hat[10:3] + g_hat[2]));
                wdata_b <= (b_hat[15]) ? 0 : ((|b_hat[14:11]) ? 255 : (b_hat[10:3] + b_hat[2]));
             end
        endcase
    end
end


endmodule
