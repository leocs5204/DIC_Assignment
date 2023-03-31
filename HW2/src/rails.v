module rails(clk, reset, data, valid, result);

input        clk;
input        reset;
input  [3:0] data;
output reg   valid;
output reg   result; 

localparam INIT = 0,
           LOAD_SEQ = 1,
           READ_NUM = 2,
           PUSH = 3,
           POP = 4,
           DONE = 5;

reg [2:0] current_state, next_state;
reg [3:0] stack[10:0];
reg [3:0] train_seq[9:0];
reg [3:0] train_wait_num, train_cnt, counter, train_index, pointer;
reg       next_data_req;

always@(posedge clk or posedge reset) begin
    if(reset)
        current_state <= INIT;
    else
        current_state <= next_state;
end

always@(*) begin
    case(current_state)
        INIT : next_state = LOAD_SEQ;
        LOAD_SEQ : next_state = (counter == train_cnt) ? READ_NUM : LOAD_SEQ;
        READ_NUM : begin
            if(stack[pointer] == train_seq[train_index])
                next_state = POP;
            else if(stack[pointer] < train_seq[train_index])
                next_state = PUSH;
            else 
                next_state = DONE;
        end
        PUSH : next_state <= (stack[pointer] < train_seq[train_index]) ? PUSH : POP;
        POP : next_state <= (train_index == train_cnt-1) ? DONE : READ_NUM;
        DONE : next_state <= next_data_req ? INIT : DONE;
    endcase
end

always@(posedge clk or posedge reset) begin
    if(reset) begin
        train_wait_num <= 1;
        train_cnt <= 0;
        train_index <= 0;
        pointer <= 0;
        counter <= 1;
        stack[0] <= 0;
        next_data_req <= 0;
        valid <= 0;
        result <= 0;
    end
    else begin
        case(current_state)
            INIT : begin
                train_cnt <= data;
                next_data_req <= 0;
            end

            LOAD_SEQ : begin
                train_seq[train_index] <= data;
                if(counter == train_cnt) begin
                    counter <= 1;
                    train_index <= 0;
                end
                else begin
                    counter <= counter + 1;
                    train_index <= train_index + 1;
                end
            end
            
            PUSH : begin
                if(stack[pointer] < train_seq[train_index]) begin
                    stack[pointer+1] <= train_wait_num;
                    train_wait_num <= train_wait_num + 1;
                    pointer <= pointer + 1;
                end
            end
        
            POP : begin
                stack[pointer] <= 0;
                pointer <= pointer - 1;
                train_index <= train_index + 1;
                if(train_index == train_cnt-1) begin
                    result <= 1;
                end
                else if(train_seq[train_index] < stack[pointer])
                    result <= 0;
            end

            DONE : begin
                if(!next_data_req) begin
                    valid <= 1;
                    next_data_req <= 1;
                end
                else begin
                    valid <= 0;
                    result <= 0;
                end
                pointer <= 0;
                train_index <= 0;
                train_wait_num <= 1;
            end

        endcase
    end
end


endmodule


/*
------------
    l10        stack[10]
------------
    l9
------------
    l8
------------
    l7
------------
    l6
------------
    l5
------------
    l4         
------------
    l3          
------------
    l2          stack[2]
------------
    l1          stack[1]
------------
    base        stack[0] <--  pointer
------------
*/