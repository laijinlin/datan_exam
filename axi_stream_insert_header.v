`timescale 1ns / 1ps
module axi_stream_insert_header #(
parameter DATA_WD = 32,
parameter DATA_BYTE_WD = DATA_WD / 8
) (
input clk,
input rst_n,
// AXI Stream input original data
input valid_in,
input [DATA_WD-1 : 0] data_in,
input [DATA_BYTE_WD-1 : 0] keep_in,
input last_in,
output ready_in,
// AXI Stream output with header inserted
output valid_out,
output [DATA_WD-1 : 0] data_out,
output [DATA_BYTE_WD-1 : 0] keep_out,
output last_out,
input ready_out,
// The header to be inserted to AXI Stream input
input valid_insert,
input [DATA_WD-1 : 0] header_insert,
input [DATA_BYTE_WD-1 : 0] keep_insert,
output ready_insert
);

reg last_in_r1;
wire last_in_pulse_p;
reg [DATA_WD-1 : 0] data_out_r1;//缓存数据
reg [DATA_BYTE_WD-1 : 0] keep_in_r;
wire axis_ready_in;


//////////////////实现data_out传输//////////////////////////

always@(posedge clk or negedge rst_n)
if(!rst_n)
    last_in_r1 <= 0;
else 
    last_in_r1 <= last_in;
assign last_in_pulse_p = ~last_in_r1 & last_in;
assign axis_ready_in = last_in_pulse_p? 0 : 1;
assign ready_in = axis_ready_in;

always@(posedge clk or negedge rst_n)
if(!rst_n)
    data_out_r1 <= 0;
else if(valid_in && axis_ready_in) 
begin
    keep_in_r <= keep_in;
    data_out_r1 <= data_in;
end
else
    data_out_r1 <= data_out_r1;//使用上升沿判断


//////////////实现header数据处理/////////////////////////////
reg [DATA_WD-1 : 0]header_out_r;
reg insert_flag;
reg [DATA_BYTE_WD-1 : 0] keep_insert_out_r;
always@(posedge clk or negedge rst_n)
if(!rst_n)
begin
    header_out_r <= 0;
    insert_flag <= 0;
end
else if(valid_insert && ready_insert)
begin
    case(keep_insert)
    4'b1111:begin header_out_r<=header_insert;insert_flag<=1; end
    4'b0111:begin header_out_r<={8'b0,header_insert[23:0]};insert_flag<=1;end
    4'b0011:begin header_out_r<={16'b0,header_insert[15:0]};insert_flag<=1;end
    4'b0001:begin header_out_r<={24'b0,header_insert[7:0]};insert_flag<=1;end
    default:begin header_out_r<=header_out_r;insert_flag<=1; end
    endcase
    keep_insert_out_r <= keep_insert;
end

////////////header插入到data////////////////

reg [DATA_WD-1 : 0]header_data_out_r;
always@(posedge clk or negedge rst_n)
if(!rst_n)
begin
    header_data_out_r <= 0;
end
else if(insert_flag)
begin
    case(keep_insert)
    4'b1111:begin header_data_out_r<=header_out_r;insert_flag<=0; end
    4'b0111:begin header_data_out_r<={header_insert[23:0],data_in[31:24]};insert_flag<=0;end
    4'b0011:begin header_data_out_r<={header_insert[15:0],data_in[31:16]};insert_flag<=0;end
    4'b0001:begin header_data_out_r<={header_insert[7:0],data_in[31:8]};insert_flag<=0;end
    default:begin header_data_out_r<=header_data_out_r;insert_flag<=0; end
    endcase
end
//else if(last_in_pulse_p)
else 
    begin
        case(keep_insert_out_r)
        4'b1111:begin header_data_out_r<=data_out_r1; end
        4'b0111:begin header_data_out_r<={data_out_r1[23:0],data_in[31:24]};end
        4'b0011:begin header_data_out_r<={data_out_r1[15:0],data_in[31:16]};end
        4'b0001:begin header_data_out_r<={data_out_r1[7:0],data_in[31:8]};end
        default:begin header_data_out_r<=header_data_out_r; end
    endcase
    end

/*
else
begin
    header_data_out_r<=header_data_out_r;
end
*/
reg s_ready_insert;
assign data_out = ready_out?header_data_out_r:data_out_r1;
always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        s_ready_insert<=0;
    else
        s_ready_insert<= insert_flag==1 ? 0:1;
end
assign ready_insert=s_ready_insert;

//////////判断valid_out
reg [1:0]insert_flag_r;
always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        insert_flag_r<=0;
    else
        insert_flag_r <= {insert_flag_r[0],insert_flag};
end
assign neg_flag = ~insert_flag_r[1]&insert_flag_r[0];
assign valid_out = neg_flag? 0 : 1;

//////////判断keep_out输出
wire last_out_p;
reg [DATA_BYTE_WD-1 : 0] keep_out_r;
always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        keep_out_r<=0;
    else if(valid_out)
        keep_out_r <= 4'b1111;
    else if(last_out_p)
    begin
        case(keep_insert)
            4'b1111:begin keep_out_r <= keep_in_r;end
            4'b0111:begin keep_out_r <= keep_in_r<<1;end
            4'b0011:begin keep_out_r <= keep_in_r<<2;end
            4'b0001:begin keep_out_r <= keep_in_r<<3;end
        endcase
    end
    else
        keep_out_r<=0;
end
assign keep_out = keep_out_r;

/////////判断last_out
reg [1:0]last_out_r;

always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        last_out_r <= 0;
    else 
    begin
        last_out_r <= {last_out_r[0],last_in_pulse_p};
    end

end

assign last_out_p = ~last_out_r[0]&last_out_r[1];
assign last_out = last_out_p;


endmodule
