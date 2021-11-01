`timescale 1ns/10ps
module	CONV(
	input 		clk,
	input 		reset,
	output	reg busy,
	input 		ready,

	output	[11:0]	iaddr,
	input	[19:0]	idata,

	output	reg	cwr,
	output	reg[11:0]	caddr_wr,
	output	reg[19:0]	cdata_wr,

	output	reg	crd,
	output	reg[11:0]	caddr_rd,
	input	[19:0]	cdata_rd,

	output	reg[2:0]	csel
	);
//reg
reg	[19:0]	kernel	[0:8];
reg	[12:0]	kernel_x;		//13bits?? cause padding_position? 2^12=4096 2^13=8192>4355
reg	[12:0]	kernel_y;
reg	[12:0]	kernel_shift_x;
reg	[12:0]	kernel_shift_y;
reg [19:0]	padding_picture;
reg	[12:0]	ker_cnt;

//wire
wire	[12:0]	kernel_position;
wire	[12:0]	padding_position;
assign 	kernel_position = kernel_x + 3*kernel_y;	
assign	padding_position = kernel_x + kernel_shift_x + 66*(kernel_y + kernel_shift_y);

reg [12:0]	kernel_position_de1;

wire	[12:0]	input_position_1;
wire	[11:0]	input_position_2;

//reg
reg		[39:0]	conv_mul;
wire 	[39:0]	conv_mul_temp;
reg 	[39:0]	conv_sum_temp [0:8];
reg		[39:0]	conv_result;
wire 	[19:0]	relu_result;

//reg_mp
reg [19:0]	mp_kernel [0:3];
reg [12:0] 	mp_kernel_x;
reg [12:0] 	mp_kernel_y;
reg [12:0]	mp_kernel_shift_x;
reg [12:0]	mp_kernel_shift_y;
reg [12:0]	max_cnt;

//wire_mp
wire	[12:0]	mp_position;
wire	[12:0]	mp_kernel_position;	
wire	[19:0]	mp_result_temp_0;
wire	[19:0]	mp_result_temp_1;
wire	[19:0]	mp_result;

assign mp_kernel_position = mp_kernel_x + 2*mp_kernel_y;
assign mp_position = mp_kernel_x + mp_kernel_shift_x + 64*(mp_kernel_y + mp_kernel_shift_y);

//
reg [3:0]   max_state;

//parameter
parameter 	IDLE = 3'd0;
parameter 	CONV = 3'd1;
parameter 	MAXPOOLING = 3'd2;
reg	[2:0]	state;
reg	[2:0]	next_state;

//FSM
always@(posedge clk)begin
	if(reset)
		state <= IDLE;
	else begin
		state <= next_state;
	end
end

//state
always@(posedge clk)begin
		case(state)
			IDLE:
				if(busy)begin
					next_state <= CONV;
				end
				else begin
					next_state <= IDLE;
				end
			CONV:
				if(ker_cnt>4097)begin		//not sure	//padding_position==4355
					next_state <= MAXPOOLING;
				end
				else begin
					next_state <= next_state;
				end
			MAXPOOLING:
				if(max_cnt>1025)begin		//not sure	//mp_position>=4095
					next_state <= IDLE;
				end
				else begin
					next_state <= MAXPOOLING;
				end
			default:next_state <= IDLE;
		endcase
end

//busy	//not sure
always@(posedge clk)begin		//negedge??
	if(reset)
		busy <= 1'd0;
	else begin
		if(ready)begin
			busy <= 1'd1;
		end	
		else if(max_cnt>=1024 && state==IDLE)begin		//work done not sure //cwr==1 && cesl==3'b011 && caddr_wr==4095
			busy <= 1'd0;
		end
		else begin 
			busy <= busy;
		end
	end
end

//cdata_wr
always@(posedge clk)begin
	if(reset)begin
		cdata_wr <= 20'd0;
	end
	else begin
		if(cwr==1 && csel==3'b001&&state==1)begin		//--state==CONV
			cdata_wr <= relu_result;
		end
		else if(cwr==1 && csel==3'b011)begin	//--state==MAXPOOLING
			cdata_wr <= mp_result;
		end
		else begin
			cdata_wr <= cdata_wr;
		end
	end
end

//cwr	*****
always@(posedge clk) begin
	if(reset) begin
		cwr<=1'd0;
	end
	else begin 
		if(kernel_position_de1==1 && ker_cnt>1&&state==1) begin
			cwr<=1'b1;
		end
		else if(max_state==4&&max_cnt>0) begin		//*****
		    cwr<=1'b1;
		end
		else begin
			cwr<=1'b0;
		end
	end
end

//crd*****
always@(posedge clk)begin
	if(reset)begin
		crd <= 1'b0;
	end
	else begin
		if(state==MAXPOOLING)begin		
			if(max_state==0||max_state==1||max_state==2||max_state==3) begin
				crd<=1'b1;
			end
		end
		else begin
			crd <= 1'b0;
		end
	end
end

//csel*****
always@(posedge clk)begin
	if(reset)begin
		csel <= 3'b000;
	end
	else begin
		if(state==CONV)begin			///not sure	//kernel_position==2.8
			csel <= 3'b001;				//when MAXPOOLING??
		end
		else if(state==MAXPOOLING&&max_state<4)begin		///not sure
			csel <= 3'b001;
		end
		else if(state==MAXPOOLING&&max_state==4) begin
			csel<=3'b011;
		end
		else begin
			csel <= 3'b001;
		end
	end
end

//caddr_wr
always@(posedge clk) begin
	if(reset) begin
		caddr_wr<=12'd0;
	end
	else begin
		if(cwr==1) begin	
		      if(ker_cnt>4096&&state==1) begin
		          caddr_wr<=caddr_wr;
		      end
		      else begin
			     caddr_wr<=caddr_wr+12'd1;
			  end
	   end
		else begin
			caddr_wr<=caddr_wr;
		end
	end
end

//caddr_rd	***
always@(posedge clk)begin
	if(reset)begin
		caddr_rd<=12'd0;
	end
	else begin
		if(crd==1)begin			//---state==MAXPOOLING		// &&csel==3'b001?
			caddr_rd<=mp_position;
		end
		else begin
			caddr_rd<=caddr_rd;
		end
	end
end

//kernel
always@(posedge reset)begin
	kernel[0] <= 20'h0A89E;
	kernel[1] <= 20'h092D5;
	kernel[2] <= 20'h06D43;
	kernel[3] <= 20'h01004;
	kernel[4] <= 20'h0708F;//F8F71
	kernel[5] <= 20'h091AC;//F6E54
	kernel[6] <= 20'h05929;//FA6D7
	kernel[7] <= 20'h037CC;//FC834
	kernel[8] <= 20'h053E7;//FAC19
end

//kernel_shift 
always@(posedge clk)begin
	if(reset==1'b1 || busy==1'b0)begin		//why busy0?
		kernel_shift_x <= 13'd0;
		kernel_shift_y <= 13'd0;
		kernel_x <= 13'd0;
		kernel_y <= 13'd0;
		ker_cnt <= 13'd0;
	end
	else begin
		if(state==CONV)begin
			if(kernel_shift_x==13'd63&&kernel_x==13'd2&&kernel_y==13'd2)begin
				kernel_shift_y <= kernel_shift_y + 1;
				kernel_shift_x <= 13'd0;
				kernel_x <= 13'd0;
				kernel_y <= 13'd0;
				ker_cnt <= ker_cnt +1;
			end
			else if(kernel_x==13'd2&&kernel_y==13'd2)begin
				kernel_shift_x <= kernel_shift_x+1;
				kernel_x <= 13'd0;
				kernel_y <= 13'd0;
				ker_cnt	<= ker_cnt +1;
			end
			else if(kernel_x==13'd2)begin
				kernel_y <= kernel_y + 1;
				kernel_x <= 13'd0;
			end
			else begin
				kernel_x <= kernel_x + 1;
			end
		end
		else begin
			kernel_shift_x <= 13'd0;
			kernel_shift_y <= 13'd0;
			kernel_x <= 13'd0;
			kernel_y <= 13'd0;
		end
	end
end

//zero-padding
always@(posedge clk)begin
	if((padding_position>=0&&padding_position<=65) || (padding_position>=4290&&padding_position<=4355) || (padding_position%66)==0 || (padding_position%66)==65)begin
		padding_picture <= 20'd0;
	end
	else begin
		padding_picture <= idata;
	end
end

always @(posedge clk)begin
	if(reset)begin
		kernel_position_de1 <= 0;
	end
	else begin
		kernel_position_de1 <= kernel_position;
	end
end

//CONV_MUL
always@(posedge clk)begin
	if(reset)begin
		conv_mul <=0;
	end
	else begin 
		if(state==CONV)begin
			if(kernel_position_de1==4 || kernel_position_de1==5 || kernel_position_de1==6 || kernel_position_de1==7 || kernel_position_de1==8)begin
				conv_mul <= (~(padding_picture * kernel[kernel_position_de1])) + 1;		//
			end
			else begin
				conv_mul <= padding_picture * kernel[kernel_position_de1];
			end
		end
	end
end

//CONV_SUM
always@(posedge clk)begin
	if(reset)begin
		conv_sum_temp[0] <= 40'd0;
		conv_sum_temp[1] <= 40'd0;
		conv_sum_temp[2] <= 40'd0;
		conv_sum_temp[3] <= 40'd0;
		conv_sum_temp[4] <= 40'd0;
		conv_sum_temp[5] <= 40'd0;
		conv_sum_temp[6] <= 40'd0;
		conv_sum_temp[7] <= 40'd0;
		conv_sum_temp[8] <= 40'd0;
	end
	else begin
		if(state==CONV)begin					//flag????
			conv_sum_temp[0] <= conv_mul;
			conv_sum_temp[1] <= conv_sum_temp[0];
			conv_sum_temp[2] <= conv_sum_temp[1];
			conv_sum_temp[3] <= conv_sum_temp[2];
			conv_sum_temp[4] <= conv_sum_temp[3];
			conv_sum_temp[5] <= conv_sum_temp[4];
			conv_sum_temp[6] <= conv_sum_temp[5];
			conv_sum_temp[7] <= conv_sum_temp[6];
			conv_sum_temp[8] <= conv_sum_temp[7];
		end
	end
end

always@(posedge clk)begin				//flag???
	if(kernel_position_de1==1 && ker_cnt>0)begin		/*kernel_position==2??*/
		conv_result <= conv_sum_temp[0] + conv_sum_temp[1] + conv_sum_temp[2] + conv_sum_temp[3] + conv_sum_temp[4] + conv_sum_temp[5] + conv_sum_temp[6] + conv_sum_temp[7] + conv_sum_temp[8];
	end
end

//rounding
assign conv_mul_temp = conv_result[15]==1 ? {conv_result[35:16]} + 20'h01311 : {conv_result[35:16] + 20'h01310} ;		//QQ

//ReLU
assign relu_result = (conv_mul_temp[19]==1) ? 20'd0 : conv_mul_temp;

//iaddr		not sure
assign input_position_1 = padding_position - 65 - 2*(kernel_shift_y+kernel_y);
assign input_position_2 = {input_position_1[11:0]};
assign iaddr = ((padding_position%66) == 0 || (padding_position%66) == 65 || (padding_position>=0&&padding_position<=65) || (padding_position>=4290&&padding_position<=4355)) ? iaddr : input_position_2;

//mp_kernel_shift 
always@(posedge clk)begin
	if(reset==1'b1 || busy==1'b0)begin		//why busy0?
		mp_kernel_shift_x <= 13'd0;
		mp_kernel_shift_y <= 13'd0;
		mp_kernel_x <= 13'd0;
		mp_kernel_y <= 13'd0;
		max_cnt <= 13'd0;
	end
	else begin
		if(state==MAXPOOLING)begin
			if(max_state==0||max_state==1||max_state==2||max_state==3) begin
			
			if(mp_kernel_shift_x==13'd62&&mp_kernel_x==13'd1&&mp_kernel_y==13'd1)begin
				mp_kernel_shift_y <= mp_kernel_shift_y + 2;
				mp_kernel_shift_x <= 13'd0;
				mp_kernel_x <= 13'd0;
				mp_kernel_y <= 13'd0;
				max_cnt <= max_cnt + 1;
			end
			else if(mp_kernel_x==13'd1&&mp_kernel_y==13'd1)begin
				mp_kernel_shift_x <= mp_kernel_shift_x + 2;
				mp_kernel_x <= 13'd0;
				mp_kernel_y <= 13'd0;
				max_cnt <= max_cnt + 1;
			end
			else if(mp_kernel_x==13'd1)begin
				mp_kernel_y <= mp_kernel_y + 1;
				mp_kernel_x <= 13'd0;
			end
			else begin
				mp_kernel_x <= mp_kernel_x + 1;
			end
			
			end
		end
		else begin
			mp_kernel_shift_x <= 13'd0;
			mp_kernel_shift_y <= 13'd0;
			mp_kernel_x <= 13'd0;
			mp_kernel_y <= 13'd0;
		end
	end
end

//mp_kernel
always@(negedge clk)begin		//negedge?
	if(reset)begin
		mp_kernel[0] <= 20'd0;
		mp_kernel[1] <= 20'd0;
		mp_kernel[2] <= 20'd0;
		mp_kernel[3] <= 20'd0;
	end
	else begin
		if(state==MAXPOOLING && crd==1)begin		//csel==3'b001?
			mp_kernel[0] <= cdata_rd;
			mp_kernel[1] <= mp_kernel[0];
			mp_kernel[2] <= mp_kernel[1];
			mp_kernel[3] <= mp_kernel[2];
		end
	end
end

//-----max_state
always@(posedge clk) begin
	if(reset)
		max_state<=3'd0;
	else begin
		if(state==MAXPOOLING) begin
			if(max_state==4) begin
				max_state<=3'd0;
			end
			else begin
				max_state<=max_state+1;
			end
		end
	end
end

//compare
assign mp_result_temp_0 = (mp_kernel[0] >= mp_kernel[1]) ? mp_kernel[0] : mp_kernel[1];
assign mp_result_temp_1 = (mp_kernel[2] >= mp_kernel[3]) ? mp_kernel[2] : mp_kernel[3];
assign mp_result = (mp_result_temp_0 >= mp_result_temp_1) ? mp_result_temp_0 :mp_result_temp_1;

endmodule
