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

reg       line_buf1_ready, line_buf2_ready, line_buf3_ready, line_buf4_ready, line_buf5_ready;
reg [7:0] line_buf1 [0 : WIDTH-1], line_buf2 [0 : WIDTH-1], line_buf3 [0 : WIDTH-1], line_buf4 [0 : WIDTH-1], line_buf5 [0 : WIDTH-1];           // declare line buffer 
reg [6:0] pixel_col, col_idx, row_idx;
reg signed [8:0] shift_reg[0:14];                          // Define shift registers
reg [13:0] wr_addr;
reg signed [15:0] g_hat, r_hat, b_hat;
wire shift_reg_ready;

integer i ;

assign shift_reg_ready = ((line_buf5_ready && pixel_col == 0) || (line_buf4_ready && pixel_col > 4));


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
        line_buf4_ready <= 0;
        line_buf5_ready <= 0;
        for(i=0; i<WIDTH; i=i+1) begin
            line_buf1[i] <= 0;
            line_buf2[i] <= 0;
            line_buf3[i] <= 0;
            line_buf4[i] <= 0;
            line_buf5[i] <= 0; 
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
        else if(!line_buf3_ready) begin
            line_buf3[pixel_col] <= data_in;
            if(pixel_col == 127)
                line_buf3_ready <= 1;
        end
        else if(!line_buf4_ready) begin
            line_buf4[pixel_col] <= data_in;
            if(pixel_col == 127)
                line_buf4_ready <= 1;
        end
        else begin
            if(pixel_col==127)
                line_buf5_ready <= 1;

            if(line_buf5_ready && (pixel_col == 0)) begin
                for(i=0; i<WIDTH; i=i+1) begin
                    line_buf1[i] <= line_buf2[i];
                    line_buf2[i] <= line_buf3[i];
                    line_buf3[i] <= line_buf4[i];
                    line_buf4[i] <= line_buf5[i];
                end
            end
            line_buf5[pixel_col] <= data_in;
            
        end
    end
end



always@(posedge clk or posedge reset) begin
    if(reset) begin
        col_idx <= 2;
        row_idx <= 2;
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


wire signed [15:0] mask_buf [0:12]; 

assign mask_buf[0]  = line_buf1[col_idx];
assign mask_buf[1]  = line_buf2[col_idx-1];
assign mask_buf[2]  = line_buf2[col_idx];
assign mask_buf[3]  = line_buf2[col_idx+1];
assign mask_buf[4]  = line_buf3[col_idx-2];
assign mask_buf[5]  = line_buf3[col_idx-1];
assign mask_buf[6]  = line_buf3[col_idx];
assign mask_buf[7]  = line_buf3[col_idx+1];
assign mask_buf[8]  = line_buf3[col_idx+2];
assign mask_buf[9]  = line_buf4[col_idx-1];
assign mask_buf[10] = line_buf4[col_idx];
assign mask_buf[11] = line_buf4[col_idx+1];
assign mask_buf[12] = line_buf5[col_idx];


// Pre Calculation
always@(*) begin
    case({row_idx[0], col_idx[0]})
        2'b11: begin              // G phase: BGGR
            // interpolate R
            r_hat = mask_buf[6] * 5 + mask_buf[2] * 4 + mask_buf[10] * 4 - mask_buf[0] - mask_buf[1] - mask_buf[3] + (mask_buf[4] >>> 1) + (mask_buf[8] >>> 1) - mask_buf[9] - mask_buf[11] - mask_buf[12];
            b_hat = mask_buf[6] * 5 + mask_buf[5] * 4 + mask_buf[7] * 4 + (mask_buf[0] >>> 1) - mask_buf[1] - mask_buf[3] - mask_buf[4] - mask_buf[8] - mask_buf[9] - mask_buf[11] + (mask_buf[12] >>> 1);
            g_hat = mask_buf[6] * 8;
        end

        2'b10: begin              // B phase: GBRG
            // interpolation G
            r_hat = (mask_buf[6] * 6) - ((mask_buf[0] * 3) >>> 1) + (mask_buf[1] * 2) + (mask_buf[3] * 2) - ((mask_buf[4] * 3) >>> 1) - ((mask_buf[8] * 3) >>> 1) + mask_buf[9] * 2 + mask_buf[11] * 2 - ((mask_buf[12] * 3) >>> 1);
            g_hat = mask_buf[2] * 2 - mask_buf[0] - mask_buf[4] + mask_buf[5] * 2 + mask_buf[6] * 4 + mask_buf[7] * 2 - mask_buf[8] + (mask_buf[10] * 2) - mask_buf[12];
            b_hat = mask_buf[6] * 8;

        end
        
        2'b00: begin              // G phase: RGGB
            // interpolate B
            r_hat = mask_buf[6] * 5 + mask_buf[5] * 4 + mask_buf[7] * 4 + (mask_buf[0] >>> 1) - mask_buf[1] - mask_buf[3] - mask_buf[4] - mask_buf[8] - mask_buf[9] - mask_buf[11] + (mask_buf[12] >>> 1); 
            b_hat = mask_buf[6] * 5 + mask_buf[2] * 4 + mask_buf[10] * 4 - mask_buf[0] - mask_buf[1] - mask_buf[3] + (mask_buf[4] >>> 1) + (mask_buf[8] >>> 1) - mask_buf[9] - mask_buf[11] - mask_buf[12];
            g_hat = mask_buf[6] * 8;
        end
        
        2'b01: begin              // R phase: GRBG
            r_hat = mask_buf[6] * 8; 
            g_hat = mask_buf[2] * 2 - mask_buf[0] - mask_buf[4] + mask_buf[5] * 2 + mask_buf[6] * 4 + mask_buf[7] * 2 - mask_buf[8] + (mask_buf[10] * 2) - mask_buf[12];
            b_hat = (mask_buf[6] * 6) - ((mask_buf[0] * 3) >>> 1) + (mask_buf[1] * 2) + (mask_buf[3] * 2) - ((mask_buf[4] * 3) >>> 1) - ((mask_buf[8] * 3) >>> 1) + mask_buf[9] * 2 + mask_buf[11] * 2 - ((mask_buf[12] * 3) >>> 1);
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

        wdata_r <= (r_hat[15]) ? 0 : ((|r_hat[14:11]) ? 255 : r_hat[10:3]);
        wdata_g <= (g_hat[15]) ? 0 : ((|g_hat[14:11]) ? 255 : g_hat[10:3]);
        wdata_b <= (b_hat[15]) ? 0 : ((|b_hat[14:11]) ? 255 : b_hat[10:3]); 

        done <= ({row_idx,col_idx} == 14'd16253);
    end
end

endmodule
