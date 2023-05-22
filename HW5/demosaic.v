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
output done;

localparam BGGR = 2'b00,
           GBRG = 2'b01,
           GRBG = 2'b11,
           RGGB = 2'b10;


reg [7:0] line_buf_matrix[382:0];
reg [8:0] line_buf_idx;
reg [6:0] line_buf, line_row;
reg       odd_even_row;
reg [7:0] green_val, red_val, blue_val;

// data is valid for calculation for interpolation 
wire cal_valid;
// Mode BGGR / GBRG / GRBG / RGGB
wire [1:0] mode;

integer i;

assign cal_valid = (line_buf_idx > 258); 
assign mode = {odd_even_row, line_buf_idx[0]};             // odd_evne_row flag decide the start point of interpolace of BGGR or GRBG, lin_buf_idx decide the interpolace of BGGR/GBRG and GRBG/RGGB 


// store Byer image pixels into line buffer matrix register. When store till 258 pixel then can start to calculate and output first pixel RGB value.
always@(posedge clk or posedge reset) begin
    if(reset) begin
        line_buf_idx <= 0;
        odd_even_row <= 1;      // start from odd row
    end
    else if(in_en) begin
        if(line_buf_idx == 383) begin               //reset to index 256， other pixels shift up a row.
            line_buf_idx <= 256;
            for(i=0; i<128; i=i+1) begin
                line_buf_matrix[i] <= line_buf_matrix[i+128];
                line_buf_matrix[i+128] <= line_buf_matrix[i+256];
            end
            odd_even_row <= ~odd_even_row;          // switch to next row
        end            
        else 
            line_buf_idx <= line_buf_idx + 1;
        
        line_buf_matrix[line_buf_idx] <= data_in;
    end
end

// row counter
always@(posedge clk or posedge reset) begin
    if(reset) begin
        line_buf <= 1;
        line_row <= 1;
    end
    else begin
        if(line_buf == 126) begin
            line_buf <= 1;
            line_row <= line_row + 1;
        end
        else
            line_buf <= line_buf + 1;
    end
end


// Bilinear Interpolation
always@(*) begin
    if(cal_valid) begin
        case(mode)
            BGGR: begin
                green_val <= line_buf_matrix[128+line_buf];
                red_val <= (line_buf_matrix[line_buf] + line_buf_matrix[line_buf+256]) >> 1;
                blue_val <= (line_buf_matrix[line_buf+127] + line_buf_matrix[line_buf+129]) >> 1;
            end
            GBRG: begin
                green_val <= (line_buf_matrix[line_buf] + line_buf_matrix[line_buf+256] + line_buf_matrix[line_buf+127] + line_buf_matrix[line_buf+129]) >> 2;
                red_val <= (line_buf_matrix[line_buf-1] + line_buf_matrix[line_buf+1] + line_buf_matrix[line_buf+255] + line_buf_matrix[line_buf+257]) >> 2;
                blue_val <= line_buf_matrix[line_buf+128];
            end

            GRBG: begin
                green_val <= (line_buf_matrix[line_buf] + line_buf_matrix[line_buf+256] + line_buf_matrix[line_buf+127] + line_buf_matrix[line_buf+129]) >> 2;
                red_val <= line_buf_matrix[line_buf+128];
                blue_val <= (line_buf_matrix[line_buf-1] + line_buf_matrix[line_buf+1] + line_buf_matrix[line_buf+255] + line_buf_matrix[line_buf+257]) >> 2;
            end

            RGGB: begin
                green_val <= line_buf_matrix[128+line_buf];
                red_val <= (line_buf_matrix[line_buf+127] + line_buf_matrix[line_buf+129]) >> 1;
                blue_val <= (line_buf_matrix[line_buf] + line_buf_matrix[line_buf+256]) >> 1;
            end
            
            default : begin
                green_val <= green_val;
                red_val <= red_val;
                blue_val <= blue_val;
            end
        endcase
    end
    else begin
        green_val <= 8'd0;
        red_val <= 8'd0;
        blue_val <= 8'd0;
    end

end


// Address and data write back to memory
always@(posedge clk or posedge reset) begin
    if(reset) begin
        addr_r <= 0;
        addr_g <= 0;
        addr_b <= 0;
    end
    else if(cal_valid) begin
        addr_r <= {line_row,line_buf};
        addr_g <= {line_row,line_buf};
        addr_b <= {line_row,line_buf};
        wr_r <= red_val;
        wr_g <= green_val;
        wr_b <= blue_val;  
    end
end



endmodule
