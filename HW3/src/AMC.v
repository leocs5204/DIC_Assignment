module AMC(clk, rst, ascii_in, ready, valid, result);

// Input signal
input clk;
input rst;
input ready;
input [7:0] ascii_in;

// Output signal
output reg valid;
output reg [6:0] result;


//-----Your design-----//
localparam DATA_READ = 0,            // Read data from testbench and do postfix transform at the same time.
           POSTFIX = 1,              // Transform infix to postfix                      
                                     // Calculate Postfix 
           FIND_AND_CALCULATE = 2,   // Read data in out_stack until the pointer meet the operator.
           SHIFT_RESULT = 3,
           RESULT_OUT = 4, 
           DONE = 5;

reg [2:0] current_state, next_state;

reg [7:0] raw_data[15:0];            // raw data read from testbench 
reg [7:0] postfix_str[15:0];         // Postfix string
reg [7:0] op_stack[7:0];             // Stack store the operators
reg [2:0] op_stack_pointer;
reg [3:0] postfix_idx, data_idx, shift_idx;
reg       postfix_ready;
reg [15:0] postfix_str_type;         // bit map: 0 is number, 1 is operator;

wire is_operator;
wire higher_equal_precedence;        // Check whether top operator in stack has higher precedence compare to current operator
wire match_cal;
wire finish;

assign is_operator = (raw_data[data_idx] == 8'd40) || (raw_data[data_idx] == 8'd41) || (raw_data[data_idx] == 8'd42) || (raw_data[data_idx] == 8'd43) || (raw_data[data_idx] == 8'd45);
assign higher_equal_precedence = (op_stack[op_stack_pointer] == 8'd42) || 
                                 ((raw_data[data_idx] == 8'd43 || raw_data[data_idx] == 8'd45) && (op_stack[op_stack_pointer] == 8'd43 || op_stack[op_stack_pointer] == 8'd45));
assign match_cal = postfix_ready && ({postfix_str_type[postfix_idx+2], postfix_str_type[postfix_idx+1], postfix_str_type[postfix_idx]} == 3'b100) ;
                   
assign finish = postfix_ready && (postfix_str[postfix_idx+1] == 61);                     //the first element is the result and the next index is "=" means the caculation is finished.

always@(posedge clk or posedge rst) begin
    if(rst) begin
        current_state <= DATA_READ;
    end
    else begin
        current_state <= next_state;
    end
end

always@(*) begin
    case(current_state)
        DATA_READ : next_state = (ascii_in == 8'd61) ? POSTFIX : DATA_READ;
        POSTFIX : next_state = ((raw_data[data_idx] == 8'd61) && (op_stack_pointer == 0)) ? FIND_AND_CALCULATE : POSTFIX;
        FIND_AND_CALCULATE : next_state = finish ? RESULT_OUT : (match_cal ? SHIFT_RESULT : FIND_AND_CALCULATE);
        SHIFT_RESULT : next_state = (postfix_str[postfix_idx+2] == 8'd61) ? FIND_AND_CALCULATE : SHIFT_RESULT;
        RESULT_OUT : next_state = DONE;
        DONE : next_state = DATA_READ;
        default: next_state = DATA_READ;
    endcase
end

always@(posedge clk or posedge rst) begin
    if(rst) begin
        postfix_idx <= 0;
        data_idx <= 0;
        op_stack_pointer <= 0;
        op_stack[0] <= 0;
        valid <= 0;
        postfix_ready <= 0;
        shift_idx <= 0;
        postfix_str_type <= 0;
    end
    else begin
        case(current_state)  
        DATA_READ : begin
            if(ascii_in >= 8'd48 && ascii_in <= 8'd58)
                raw_data[data_idx] <= ascii_in - 8'd48;
            else if(ascii_in >= 8'd97 && ascii_in <= 8'd102)
                raw_data[data_idx] <= ascii_in - 8'd87;
            else 
                raw_data[data_idx] <= ascii_in; 
            data_idx <= (ascii_in == 8'd61) ? 0 : data_idx + 1;
        end

        POSTFIX : begin
            if(!(raw_data[data_idx] == 8'd61)) begin
                if(is_operator) begin 
                    if(higher_equal_precedence) begin                                   // Pop the top operator in stack to posfix string and push current operator.
                        postfix_str[postfix_idx] <= op_stack[op_stack_pointer];
                        postfix_str_type[postfix_idx] <= 1'b1;
                        op_stack_pointer <= op_stack_pointer - 1;
                        postfix_idx <= postfix_idx + 1;
                    end
                    else if(raw_data[data_idx] == 8'd41) begin                          // If meet ")" then pop the operator
                        postfix_str[postfix_idx] <= op_stack[op_stack_pointer];
                        postfix_str_type[postfix_idx] <= 1'b1;
                        op_stack_pointer <= op_stack_pointer - 2;                       // Skip operator "("
                        postfix_idx <= postfix_idx + 1;
                    end
                    else begin                                                          // Push the current operator to stack.
                        op_stack[op_stack_pointer+1] <= raw_data[data_idx];
                        data_idx <= data_idx + 1;
                        op_stack_pointer <= op_stack_pointer + 1;
                    end
                end
                else begin
                    postfix_str[postfix_idx] <= raw_data[data_idx];                     // Output operand to postfix string
                    postfix_idx <= postfix_idx + 1;
                    data_idx <= data_idx + 1;
                end
            end
            else begin                                                                  // Pop the rest of operators to postfix string                                              
                if(op_stack_pointer > 0) begin
                    postfix_str_type[postfix_idx] <= 1'b1;    
                    postfix_str[postfix_idx] <= op_stack[op_stack_pointer];
                    postfix_idx <= postfix_idx + 1;
                    op_stack_pointer <= op_stack_pointer - 1;
                end
                else begin
                    postfix_str[postfix_idx] <= 8'd61;
                    postfix_idx <= 0;
                    postfix_ready <= 1;
                end     
            end
        end

        FIND_AND_CALCULATE : begin
            if(match_cal) begin
                case(postfix_str[postfix_idx+2])
                    // '*'
                    8'd42: begin
                        postfix_str[postfix_idx] <= postfix_str[postfix_idx] * postfix_str[postfix_idx+1];
                    end
                    // '+'
                    8'd43: begin
                        postfix_str[postfix_idx] <= postfix_str[postfix_idx] + postfix_str[postfix_idx+1];
                    end
                    // '-'
                    8'd45: begin
                        postfix_str[postfix_idx] <= postfix_str[postfix_idx] - postfix_str[postfix_idx+1];
                    end   
                endcase
            end
                postfix_idx <= postfix_idx + 1;

        end

        SHIFT_RESULT : begin             // shift the rest elements 2 index front. the shift will end when tail elements meet "="
            postfix_str[postfix_idx] <= postfix_str[postfix_idx+2];
            postfix_str_type[postfix_idx] <= postfix_str_type[postfix_idx+2];
            postfix_idx <= (postfix_str[postfix_idx+2] == 8'd61) ? 0 : postfix_idx + 1;               
        end

        RESULT_OUT : begin
            result <= postfix_str[0];
            valid <= 1;
        end

        DONE : begin
            valid <= 0;
            postfix_idx <= 0;
            data_idx <= 0;
            op_stack_pointer <= 0;
            postfix_ready <= 0;
        end

        endcase
    end
end



endmodule