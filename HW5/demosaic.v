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

localparam INIT = 0,
           S_LINE1 = 1,
           S_LINE2 = 2,
           S_135_ODD = 3,
           S_24_ODD = 4,
           S_24_EVEN = 5,
           S_135_EVEN = 6,
           DONE = 7;

reg [3:0] current_state, next_state;
reg [7:0] line_buf1 [0 : WIDTH-1], line_buf2 [0 : WIDTH-1];            // declare line buffer 
reg [6:0] pixel_col;
reg [7:0] V1, V2, V3, V4, V5, V6, V7, V8, V9;                          // Define shift register
reg [8:0] r1, r2, r3, r4, r5, r6, r7, r8, r9, r10, r11, r12, r13;      // pipeline registers
reg [17:0] c;
reg [13:0] wr_addr;


always@(posedge clk or posedge reset) begin 
    if(reset) begin
        current_state <= INIT;
    end
    else begin
        current_state <= next_state;
    end
end


always@(*) begin
    case(current_state)
        INIT : next_state = in_en ? S_LINE1 : INIT;

        S_LINE1 : next_state = (pixel_col == (WIDTH-1)) ? S_LINE2 : S_LINE1;

        S_LINE2 : next_state = (pixel_col == (WIDTH-1)) ? S_135_ODD : S_LINE2;

        S_135_ODD : next_state = S_24_ODD;
        
        S_24_ODD : next_state = (pixel_col == (WIDTH-1)) ? S_24_EVEN : S_135_ODD;

        S_24_EVEN : next_state = S_135_EVEN;

        S_135_EVEN : next_state = (pixel_col == (WIDTH-1)) ? ( wr_addr == (HEIGHT-1) ? DONE : S_135_ODD) : S_24_EVEN;

        DONE : next_state = !in_en ? INIT : DONE;

        default : next_state = INIT;
    endcase
end

always@(*) begin
     case(current_state)

        S_135_ODD : c = 18'b00_0010_0010_0000_0110;
        
        S_24_ODD : c = 18'b11_1101_1101_1111_1001;

        S_24_EVEN : c = 18'b11_1101_1101_1111_1001;

        S_135_EVEN : c = 18'b00_0010_0010_0000_0110;

        default : c = c;
    endcase
end

// line buffer behavior  and shift register storage
always@(posedge clk or posedge reset) begin
    if(reset) begin
        pixel_col <= 7'd0;
        V1 <= 8'd0; 
        V2 <= 8'd0; 
        V3 <= 8'd0;
        V4 <= 8'd0;
        V5 <= 8'd0;
        V6 <= 8'd0;
        V7 <= 8'd0;
        V8 <= 8'd0;
        V9 <= 8'd0;
    end
    else begin
        case(current_state)
            INIT : begin
                wr_r <= 0;
                wr_b <= 0;
                wr_g <= 0;
            end

            S_LINE1 : begin
                line_buf1[pixel_col] <= data_in;
                pixel_col <= pixel_col + 1;
            end

            S_LINE2 : begin 
                line_buf2[pixel_col] <= data_in;
                pixel_col <= pixel_col + 1;
            end

            S_135_ODD : begin
                V1 <= V2;
                V2 <= V3; 
                V3 <= V4;
                V4 <= V7;
                V5 <= V8;
                V6 <= V9;                
                V7 <= line_buf1[pixel_col];
                V8 <= line_buf2[pixel_col];
                V9 <= data_in;
                line_buf1[pixel_col] <= data_in;             // store new row data into line buffer 1 at the same time.
            end

            S_24_ODD : begin
                V1 <= V2;
                V2 <= V3; 
                V3 <= V4;
                V4 <= V7;
                V5 <= V8;
                V6 <= V9; 
                V7 <= line_buf1[pixel_col];
                V8 <= line_buf2[pixel_col];
                V9 <= data_in;
                line_buf1[pixel_col] <= data_in;             // store new row data into line buffer 1 at the same time.
            end

            S_135_ODD : begin
                V1 <= V2;
                V2 <= V3; 
                V3 <= V4;
                V4 <= V7;
                V5 <= V8;
                V6 <= V9;                
                V7 <= line_buf1[pixel_col];
                V8 <= line_buf2[pixel_col];
                V9 <= data_in;
                line_buf2[pixel_col] <= data_in;             // store new row data into line buffer 2 at the same time.
            end

            S_24_ODD : begin
                V1 <= V2;
                V2 <= V3; 
                V3 <= V4;
                V4 <= V7;
                V5 <= V8;
                V6 <= V9; 
                V7 <= line_buf2[pixel_col];
                V8 <= line_buf1[pixel_col];
                V9 <= data_in;
                line_buf2[pixel_col] <= data_in;             // store new row data into line buffer 2 at the same time.
            end

        endcase
    end
end

// Calculation of each stage
always@(posedge clk or posedge reset) begin
    if(reset) begin

    end
    else begin
        case(current_state)
            S_135_ODD : begin 
                // Stage 1
                r1 <= V7 + V9;
                r2 <= (V7 > V9) ? V7 - V9 : V9 - V7;
                r3 <= V4 + V6;

                // Stage 3 
                r4 <= ((r11 << 1) + r11) >> 3 + r12;
                r5 <= r2 ? (V1 + V8) >> 4 : (((V1+V8) << 1) + (V1 + V8)) >> 4;
                r6 <= V5 + ((V3 + V8) >> 1);
                r7 <= r7;
                r8 <= r3 + V4 + V6;
                r9 <= (V4 + V6) >> 1;
                r10 <= r1;

                // Stage 5
                
            end
        endcase
    end
end


endmodule
