`timescale 1ns/10ps
module  ATCONV(
	input		clk,
	input		reset,
	output	reg	busy,	
	input		ready,	
			
	output  reg	 [11:0]	iaddr,
	input signed [12:0]	idata,
	
	output	reg 	cwr,
	output  reg	[11:0]	caddr_wr,
	output reg 	[12:0] 	cdata_wr,
	
	output	reg 	crd,
	output reg	[11:0] 	caddr_rd,
	input 	[12:0] 	cdata_rd,

	output reg 	csel
	);

/*
- input image size: 64 x 64 0~4095
- idata: 9 bits integer, 4 bits float  Q9.4 FIXED POINT
- csel : 0 --> layer0 (conv output)  1 --> layer2 (max pool output)

replication padding mode description:
>>> m = nn.ReplicationPad2d(2)
>>> input = torch.arange(9, dtype=torch.float).reshape(1, 1, 3, 3)
>>> input
tensor([[[[0., 1., 2.],
          [3., 4., 5.],
          [6., 7., 8.]]]])
>>> m(input)
tensor([[[[0., 0., 0., 1., 2., 2., 2.],
          [0., 0., 0., 1., 2., 2., 2.],
          [0., 0., 0., 1., 2., 2., 2.],
          [3., 3., 3., 4., 5., 5., 5.],
          [6., 6., 6., 7., 8., 8., 8.],
          [6., 6., 6., 7., 8., 8., 8.],
          [6., 6., 6., 7., 8., 8., 8.]]]])
*/


parameter INIT = 0,
          //Layer 0
		  PRE_CONV = 1,
          GET_DATA = 2,
		  CONV = 3,
		  POST_CONV = 4,
		  ADDBIAS = 5,
		  RELU = 6,
		  LOAD_L0 = 7,
		  //Layer 1
          GET_DATA2 = 8,
		  MAXPOOLING = 9,
		  POST_MXPOL = 10,
		  //Layer 2
		  DONE = 11;

reg                add_bit;
reg 		[3:0]  current_state, next_state;
reg 		[5:0]  curr_addr_x, curr_addr_y;
reg 		[3:0]  idx, cnt;
reg  signed [19:0] temp_sum;    // temp sum for kernel*pixel
reg  signed [15:0] sum_result;
reg  signed [12:0] kernel_val, kernel_val2;
reg         [1:0]  mp_idx;
reg         [9:0]  l1_addr;
reg  signed [12:0] idata_temp;
reg         [12:0] cdata_rd_temp;
wire 		[11:0] peri_addr[0:8];  // peripheral address of current addr
wire        [11:0] mp_addr[0:3];
wire 			   is_replic_padding[0:8];
wire        [11:0] padding_addr[0:8];
wire        [5:0]  padding_area;
wire               round_bit;

wire signed [12:0] kernel [0:8];
wire signed [12:0] bias;

assign bias = 13'h1FF4;
assign kernel[0] = 13'h1FFF; 
assign kernel[1] = 13'h1FFE; 
assign kernel[2] = 13'h1FFF;
assign kernel[3] = 13'h1FFC; 
assign kernel[4] = 13'h0010; 
assign kernel[5] = 13'h1FFC;
assign kernel[6] = 13'h1FFF; 
assign kernel[7] = 13'h1FFE; 
assign kernel[8] = 13'h1FFF;

assign is_replic_padding[0] = (curr_addr_x < 6'd2) || (curr_addr_y < 6'd2);
assign is_replic_padding[1] = (curr_addr_y < 6'd2);
assign is_replic_padding[2] = (curr_addr_x > 6'd61) || (curr_addr_y < 6'd2);
assign is_replic_padding[3] = (curr_addr_x < 6'd2);
assign is_replic_padding[4] = 0;
assign is_replic_padding[5] = (curr_addr_x > 6'd61);
assign is_replic_padding[6] = (curr_addr_x < 6'd2) || (curr_addr_y > 6'd61);
assign is_replic_padding[7] = (curr_addr_y > 6'd61);
assign is_replic_padding[8] = (curr_addr_x > 6'd61) || (curr_addr_y > 6'd61);

assign padding_area[0] = ({curr_addr_y, curr_addr_x} == 0) || ({curr_addr_y, curr_addr_x} == 1) || ({curr_addr_y, curr_addr_x} == 64) || ({curr_addr_y, curr_addr_x} == 65);                  //top left corner, padding address 0;
assign padding_area[1] = ({curr_addr_y, curr_addr_x} == 62) || ({curr_addr_y, curr_addr_x} == 63) || ({curr_addr_y, curr_addr_x} == 126) || ({curr_addr_y, curr_addr_x} == 127);	          //top right corner, padding address 63;
assign padding_area[2] = ({curr_addr_y, curr_addr_x} == 3968) || ({curr_addr_y, curr_addr_x} == 3969) || ({curr_addr_y, curr_addr_x} == 4032) || ({curr_addr_y, curr_addr_x} == 4033);		  //bottom left corner, padding address 4032;
assign padding_area[3] = ({curr_addr_y, curr_addr_x} == 4030) || ({curr_addr_y, curr_addr_x} == 4031) || ({curr_addr_y, curr_addr_x} == 4094) || ({curr_addr_y, curr_addr_x} == 4095);	      //bottom right corner, padding address 4095;
assign padding_area[4] = (curr_addr_x < 2) && (curr_addr_y > 1) && (curr_addr_y < 62);
assign padding_area[5] = (curr_addr_x > 61) && (curr_addr_y > 1) && (curr_addr_y < 62);


assign padding_addr[0] = padding_area[0] ? 12'd0 : (padding_area[2] ? ({curr_addr_y, 6'd0} - 128) : (padding_area[4] ? ({curr_addr_y, 6'd0} - 128) : (curr_addr_x - 2)));
assign padding_addr[1] = {6'b00_0000, curr_addr_x};
assign padding_addr[2] = padding_area[1] ? 12'd63 : (padding_area[3] ? ({curr_addr_y, 6'd63} - 128) : (padding_area[5] ? ({curr_addr_y, 6'd63} - 128) : (curr_addr_x + 2)));
assign padding_addr[3] = {curr_addr_y, 6'd0};
assign padding_addr[4] = 0;
assign padding_addr[5] = {curr_addr_y, 6'd63};
assign padding_addr[6] = padding_area[2] ? 12'd4032 : (padding_area[0] ? ({curr_addr_y, 6'd0} + 128) : (padding_area[4] ? ({curr_addr_y, 6'd0} + 128) : ({6'b11_1111, curr_addr_x} - 2)));
assign padding_addr[7] = {6'b11_1111, curr_addr_x};
assign padding_addr[8] = padding_area[3] ? 12'd4095 : (padding_area[1] ? ({curr_addr_y, 6'd63} + 128) : (padding_area[5] ? ({curr_addr_y, 6'd63} + 128) : ({6'b11_1111, curr_addr_x} + 2)));

assign peri_addr[0] = {curr_addr_y, curr_addr_x} - 130;
assign peri_addr[1] = {curr_addr_y, curr_addr_x} - 128;
assign peri_addr[2] = {curr_addr_y, curr_addr_x} - 126;
assign peri_addr[3] = {curr_addr_y, curr_addr_x} - 2;
assign peri_addr[4] = {curr_addr_y, curr_addr_x};
assign peri_addr[5] = {curr_addr_y, curr_addr_x} + 2;
assign peri_addr[6] = {curr_addr_y, curr_addr_x} + 126;
assign peri_addr[7] = {curr_addr_y, curr_addr_x} + 128;
assign peri_addr[8] = {curr_addr_y, curr_addr_x} + 130;

assign mp_addr[0] = {curr_addr_y, curr_addr_x};
assign mp_addr[1] = {curr_addr_y, curr_addr_x} + 1;
assign mp_addr[2] = {curr_addr_y, curr_addr_x} + 64;
assign mp_addr[3] = {curr_addr_y, curr_addr_x} + 65;


assign round_bit = temp_sum[19] ? (temp_sum[3] & (|temp_sum[2:0])) : temp_sum[3];

always@(posedge clk or posedge reset) begin
	if(reset) begin
		current_state <= 0;
	end
	else begin
		current_state <= next_state;
	end
end

always@(*) begin
	case(current_state)
		INIT: next_state = PRE_CONV;
		PRE_CONV : next_state = GET_DATA;
        GET_DATA : next_state = CONV;
		CONV: next_state = (cnt == 8) ? POST_CONV : CONV;
		POST_CONV : next_state = ADDBIAS;
		ADDBIAS : next_state = RELU;
		RELU: next_state = (({curr_addr_y, curr_addr_x} == 4095) ? LOAD_L0 : PRE_CONV);
		LOAD_L0 : next_state = GET_DATA2;
        GET_DATA2 : next_state = MAXPOOLING;
		MAXPOOLING : next_state = (mp_idx == 3) ? POST_MXPOL : LOAD_L0;
		POST_MXPOL: next_state = (({curr_addr_y, curr_addr_x} == 4030) ? DONE : LOAD_L0); 
		DONE: next_state = DONE;
		default: next_state = INIT;
	endcase
end

always@(posedge clk or posedge reset) begin
	if(reset) begin
		iaddr <= 12'd0;
		caddr_rd <= 12'd0;
		caddr_wr <= 12'd0;
		cdata_wr <= 13'd0;
		cwr <= 1'b0;
		busy <= 1'b0;
		csel <= 1'b0;
		idx <= 4'd0;
		curr_addr_x <= 6'd0;
        curr_addr_y <= 6'd0;
		temp_sum <= 20'd0;
		sum_result <= 16'd0;
		add_bit <= 1'b0;
		mp_idx <= 2'b00;
		l1_addr <= 10'd0;
        cdata_rd_temp <= 13'd0;
        cnt <= 0;
	end
	else begin
		case(current_state)
			INIT: begin
				busy <= ready; 
			end

			PRE_CONV: begin
				cwr <= 0;
				if(!is_replic_padding[idx]) begin 
                    iaddr <= (idx < 9) ? peri_addr[idx] : iaddr;
				end
				else begin   // is replicate padding, find the padding number
					iaddr <= padding_addr[idx];
				end
				kernel_val <= kernel[idx];
                idx <= (idx==8) ? 0 : idx + 1; 
			end

            GET_DATA: begin
                idata_temp <= idata;
                if(!is_replic_padding[idx]) begin 
					iaddr <= (idx < 9) ? peri_addr[idx] : iaddr;
				end
				else begin   // is replicate padding, find the padding number
					iaddr <= padding_addr[idx];
				end
                kernel_val2 <= kernel_val;
				kernel_val <= kernel[idx];
                idx <= (idx==8) ? 0 : idx + 1; 
            end

			CONV: begin
                idata_temp <= idata;
				temp_sum <= temp_sum + idata_temp * kernel_val2;
				idx <= (idx==8) ? 0 : idx + 1; 
                cnt <= cnt + 1;
                if(!is_replic_padding[idx]) begin 
					iaddr <= (idx < 9) ? peri_addr[idx] : iaddr;
                    //head_addr <= head_addr + 1;
				end
				else begin   // is replicate padding, find the padding number
					iaddr <= padding_addr[idx];
				end
                kernel_val2 <= kernel_val;
				kernel_val <= kernel[idx];
			end

			POST_CONV: begin            // Do rounding
				sum_result <= temp_sum[19:4] + round_bit;
				temp_sum <= 0;
			end

			ADDBIAS: begin
				sum_result <= sum_result + bias;
			end

			RELU: begin
				cwr <= 1;
				caddr_wr <= {curr_addr_y, curr_addr_x};
				csel <= 1'b0;
				caddr_wr <= {curr_addr_y, curr_addr_x};
				cdata_wr <= (sum_result > 0) ? sum_result : 0;
				idx <= 0;										// initial register back to next pixel to do convolution
                cnt <= 0;
				if(curr_addr_y == 63) begin
                    if(curr_addr_x == 63) begin
                        curr_addr_x <= 0;
                        curr_addr_y <= 0;
                    end
                    else
                        curr_addr_x <= curr_addr_x + 1;
                end
                else begin
                    if(curr_addr_x == 63) begin
                        curr_addr_x <= 0;
                        curr_addr_y <= curr_addr_y + 1;
                    end
                    else
                        curr_addr_x <= curr_addr_x + 1;
                end
			end

			LOAD_L0: begin
				crd <= 1;
				cwr <= 0;
				csel <= 1'b0; 
				caddr_rd <= mp_addr[mp_idx];
			end

            GET_DATA2: begin
                cdata_rd_temp <= cdata_rd;
            end

			MAXPOOLING: begin
				crd <= 0;
				temp_sum <= (cdata_rd_temp > temp_sum) ? cdata_rd_temp : temp_sum;
				mp_idx <= (mp_idx == 3) ? 0 : mp_idx + 1;
			end

			POST_MXPOL: begin
				cwr <= 1;
				csel <= 1'b1;
				caddr_wr <= l1_addr;
				cdata_wr <= (temp_sum > 0) ? ((temp_sum[3:0] > 0) ? ({temp_sum[12:4], 4'b0000} + 8'h10) : {temp_sum[12:4], 4'b0000}) : 13'd0;
				l1_addr <= ((l1_addr == 1023) ? 0: l1_addr + 1);
				if(curr_addr_x == 62) begin
                    curr_addr_x <= 0;
                    curr_addr_y <= curr_addr_y + 2;
                end
                else
                    curr_addr_x <= curr_addr_x + 2;
                temp_sum <= 0;
			end
			
			DONE: begin
				busy <= 0;
			end
		endcase
	end
end



endmodule