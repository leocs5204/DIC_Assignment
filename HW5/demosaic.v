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

reg       line_buf1_ready, line_buf2_ready;
reg [7:0] line_buf1 [0 : WIDTH-1], line_buf2 [0 : WIDTH-1], line_buf3 [0 : WIDTH-1];            // declare line buffer 
reg [6:0] pixel_col, col_idx, row_idx;
reg [7:0] shift_reg[0:14];                          // Define shift registers
reg [13:0] wr_addr;
wire [7:0] KB_l, KB_r, KR_l, KR_r;
wire [8:0] GH, GV;


integer i ;

assign KB_l = shift_reg[4] - ((shift_reg[1] + shift_reg[7]) >> 1);       //G - (R left + R right)/2
assign kB_r = shift_reg[10] - ((shift_reg[7] + shift_reg[13]) >> 1);     
assign GH = shift_reg[7] + (KB_l + KB_r) >> 1;
assign GV = (shift_reg[6] + shift_reg[8]) >> 1;

always@(posedge clk or posedge reset) begin
    if(reset) begin
        for(i=0; i<WIDTH; i=i+1) begin
            line_buf1[i] <= 0;
            line_buf2[i] <= 0;
            line_buf3[i] <= 0;
        end
    end    
    else if(in_en) begin
        if(!line_buf1_ready) 
            line_buf1[pixel_col] <= data_in;
        else if(line_buf2_ready) 
            line_buf2[pixel_col] <= data_in;
        else begin
            if(pixel_col==0) begin
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


// Calculation
always@(posedge clk or posedge reset) begin
    if(reset) begin
        col_idx <= 1;
        row_idx <= 1;
    end
end


endmodule
