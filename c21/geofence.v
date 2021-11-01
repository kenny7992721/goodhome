module geofence ( clk,reset,X,Y,R,valid,is_inside);
input clk;
input reset;
input [9:0] X;
input [9:0] Y;
input [10:0] R;
output valid;
output is_inside;
reg valid;
reg is_inside;

//reg and params
reg [4:0] cs,ns;

reg [4:0] input_cnt;
reg [10:0] in_x0;
reg [10:0] in_y0;
reg [11:0] in_r0;

reg [10:0] x0 [5:0];
reg [10:0] y0 [5:0];
reg [11:0] r0 [5:0];

reg [4:0] vector_cnt, vector_cnt2;
reg [10:0] ori_x0, ori_y0;
reg [10:0] vector_x0 [5:0];
reg [10:0] vector_y0 [5:0];

reg [4:0] sort_cnt;
reg [4:0] sort_a, sort_b, sort_c, sort_d, sort_e;
reg [10:0] sort_x0 [5:0];
reg [10:0] sort_y0 [5:0];
reg [11:0] sort_r0 [5:0];

reg [4:0] heron_cnt, heron_cnt2;
reg [10:0] sqrt_o, sqrt_o2;

reg [4:0] tri_cnt;
reg [11:0] tri_s [5:0];
reg [11:0] tri_a [5:0];
reg [11:0] tri_b [5:0];
reg [11:0] tri_c [5:0];

reg [21:0] area_of6;
reg [21:0] area_of7;

wire [20:0] fin_of6;
wire [21:0] fin_of7;

parameter IDLE      =5'd0;
parameter OP_input  =5'd1;
parameter OP_vector	=5'd2;
parameter OP_sort   =5'd3;
parameter OP_sort2  =5'd4;
parameter OP_vector2=5'd5;
parameter OP_heron1 =5'd6;
parameter OP_heron2 =5'd7;
parameter OP_output =5'd8;

//for a*b+-c*d
reg [10:0] acc_a, acc_b, acc_c ,acc_d;
reg opt;
wire [21:0] acc_out;

acc a1(
.i_a(acc_a),
.i_b(acc_b),
.i_c(acc_c),
.i_d(acc_d),
.opt(opt),
.o_answer(acc_out)
);

reg [10:0] mul_a, mul_b, mul_c ,mul_d;
wire [21:0] mul_out, mul_out2;

mul m1(
.i_a(mul_a),
.i_b(mul_b),
.o_answer(mul_out)
);

mul m2(
.i_a(mul_c),
.i_b(mul_d),
.o_answer(mul_out2)
);

//state
always@(posedge clk or posedge reset) begin
    if(reset) begin
        cs<=IDLE;
    end
	else begin
        cs<=ns;
    end
end

//stage control
always@(posedge clk) begin
    case(cs)
		IDLE      :ns=OP_input;
        OP_input  :ns=(input_cnt>=5) ? OP_vector : OP_input;
        OP_vector :ns=(vector_cnt>=4) ? OP_sort : OP_vector;
		OP_sort	  :ns=(sort_cnt>=10) ? OP_sort2 : OP_sort;
		OP_sort2  :ns=OP_vector2;
		OP_vector2:ns=(vector_cnt2>=5) ? OP_heron1 : OP_vector2;
		OP_heron1 :ns=(heron_cnt>=8) ? OP_heron2 : OP_heron1;
		OP_heron2 :ns=(tri_cnt>=9) ? OP_output : OP_heron2;
		OP_output :ns=OP_input;
		default   :ns=IDLE;
    endcase
end

//data input
always@(posedge clk or posedge reset) begin
    if(reset) begin
        in_x0<=0;
        in_y0<=0;
        in_r0<=0;
    end
	else begin
        in_x0<=X;
        in_y0<=Y;
        in_r0<=R;
    end
end

//input stage and data
always@(posedge clk or posedge reset) begin
    if(reset) begin
        x0[input_cnt]<=0;
        y0[input_cnt]<=0;
        r0[input_cnt]<=0;
    end
	else begin
        if(cs==OP_input) begin
			x0[input_cnt-1]<=in_x0;
			y0[input_cnt-1]<=in_y0;
			r0[input_cnt-1]<=in_r0;
        end
		else begin
            x0[0]<=x0[0];
            y0[0]<=y0[0];
            r0[0]<=r0[0];
        end
    end
end

always@(posedge clk or posedge reset) begin
    if(reset) begin
        input_cnt<=0;
    end
	else begin
        if(cs==OP_input) begin
            input_cnt<=input_cnt+1;
        end
		else begin
		    input_cnt<=0;
        end
    end
end

//vector stage 
always@(posedge clk or posedge reset) begin
    if(reset) begin
        ori_x0<=0;
        ori_y0<=0;
    end
	else begin
        if(cs==OP_vector) begin
			ori_x0<=x0[0];
            ori_y0<=y0[0];
        end
		else begin
            ori_x0<=ori_x0;
            ori_y0<=ori_y0;
        end
    end
end

always@(posedge clk or posedge reset) begin
    if(reset) begin
        vector_cnt<=0;
    end
	else begin
        if(cs==OP_vector) begin
            vector_cnt<=vector_cnt+1;
        end
		else begin
		    vector_cnt<=0;
        end
    end
end

//vector generate
always@(posedge clk or posedge reset) begin
    if(reset) begin
        vector_x0[vector_cnt-1]<=0;
        vector_y0[vector_cnt-1]<=0;
    end
	else begin
        if(cs==OP_vector) begin
			vector_x0[vector_cnt-1]<=x0[vector_cnt]+((~ori_x0)+1);
            vector_y0[vector_cnt-1]<=y0[vector_cnt]+((~ori_y0)+1);
        end
        else if(cs==OP_vector2) begin
            vector_x0[0]<=sort_x0[1]+((~sort_x0[0])+1);
            vector_y0[0]<=sort_y0[1]+((~sort_y0[0])+1);
            
            vector_x0[1]<=sort_x0[2]+((~sort_x0[1])+1);
            vector_y0[1]<=sort_y0[2]+((~sort_y0[1])+1);
            
            vector_x0[2]<=sort_x0[3]+((~sort_x0[2])+1);
            vector_y0[2]<=sort_y0[3]+((~sort_y0[2])+1);
            
            vector_x0[3]<=sort_x0[4]+((~sort_x0[3])+1);
            vector_y0[3]<=sort_y0[4]+((~sort_y0[3])+1);
            
            vector_x0[4]<=sort_x0[5]+((~sort_x0[4])+1);
            vector_y0[4]<=sort_y0[5]+((~sort_y0[4])+1);
            
            vector_x0[5]<=sort_x0[0]+((~sort_x0[5])+1);
            vector_y0[5]<=sort_y0[0]+((~sort_y0[5])+1);
        end
        else begin
            vector_x0[0]<=vector_x0[0];
            vector_y0[0]<=vector_y0[0];
        end
    end
end

always@(posedge clk or posedge reset) begin
    if(reset) begin
        sort_cnt<=0;
    end
	else begin
        if(cs==OP_sort) begin
            sort_cnt<=sort_cnt+1;
        end
		else begin
		    sort_cnt<=0;
        end
    end
end

always@(posedge clk or posedge reset) begin
    if(reset) begin
        vector_cnt2<=0;
    end
	else begin
        if(cs==OP_vector2) begin
            vector_cnt2<=vector_cnt2+1;
        end
		else begin
		    vector_cnt2<=0;
        end
    end
end

always@(posedge clk or posedge reset) begin
    if(reset) begin
        heron_cnt<=0;
    end
	else begin
        if(cs==OP_heron1) begin
            heron_cnt<=heron_cnt+1;
        end
		else begin
		    heron_cnt<=0;
        end
    end
end

always@(posedge clk or posedge reset) begin
    if(reset) begin
        tri_cnt<=0;
    end
	else begin
        if(cs==OP_heron2) begin
            tri_cnt<=tri_cnt+1;
        end
		else begin
		    tri_cnt<=0;
        end
    end
end

//sort control
always@(posedge clk or posedge reset) begin
	if(reset) begin
		sort_a<=0;
		sort_b<=0;
		sort_c<=0;
		sort_d<=0;
		sort_e<=0;
	end
	else begin
		if(cs==OP_sort) begin
			case(sort_cnt)
				1		:begin 
				            if(acc_out[21]==1) sort_b<=sort_b+1;
				            else sort_a<=sort_a+1;
				        end
				2   	:begin 
                            if(acc_out[21]==1) sort_c<=sort_c+1;
                            else sort_a<=sort_a+1;
                        end
				3   	:begin 
                            if(acc_out[21]==1) sort_d<=sort_d+1;
                            else sort_a<=sort_a+1;
                        end
				4		:begin 
                            if(acc_out[21]==1) sort_e<=sort_e+1;
                            else sort_a<=sort_a+1;
                        end
				5   	:begin 
                            if(acc_out[21]==1) sort_c<=sort_c+1;
                            else sort_b<=sort_b+1;
                        end
				6   	:begin 
                            if(acc_out[21]==1) sort_d<=sort_d+1;
                            else sort_b<=sort_b+1;
                        end
				7		:begin 
                            if(acc_out[21]==1) sort_e<=sort_e+1;
                            else sort_b<=sort_b+1;
                        end
				8		:begin 
                            if(acc_out[21]==1) sort_d<=sort_d+1;
                            else sort_c<=sort_c+1;
                        end
				9		:begin 
                            if(acc_out[21]==1) sort_e<=sort_e+1;
                            else sort_c<=sort_c+1;
                        end
				10		:begin 
                            if(acc_out[21]==1) sort_e<=sort_e+1;
                            else sort_d<=sort_d+1;
                        end
				default	:begin
							sort_a<=sort_a;
                            sort_b<=sort_b;
                            sort_c<=sort_c;
                            sort_d<=sort_d;
                            sort_e<=sort_e;
						end
			endcase
		end
		else if(cs==OP_input) begin
		    sort_a<=0;
            sort_b<=0;
            sort_c<=0;
            sort_d<=0;
            sort_e<=0;
		end
		else begin
			sort_a<=sort_a;
            sort_b<=sort_b;
            sort_c<=sort_c;
            sort_d<=sort_d;
            sort_e<=sort_e;
		end
	end
end

//sort for the point in sort2
always@(posedge clk or posedge reset) begin
    if(reset) begin
        sort_x0[0]<=0;
        sort_y0[0]<=0;
        sort_r0[0]<=0;
    end
	else begin
        if(cs==OP_sort2) begin
            sort_x0[0]<=x0[0];
            sort_y0[0]<=y0[0];
            sort_r0[0]<=r0[0];
            
			sort_x0[sort_a+1]<=x0[1];
            sort_y0[sort_a+1]<=y0[1];
            sort_r0[sort_a+1]<=r0[1];
            
            sort_x0[sort_b+1]<=x0[2];
            sort_y0[sort_b+1]<=y0[2];
            sort_r0[sort_b+1]<=r0[2];
            
            sort_x0[sort_c+1]<=x0[3];
            sort_y0[sort_c+1]<=y0[3];
            sort_r0[sort_c+1]<=r0[3];
            
            sort_x0[sort_d+1]<=x0[4];
            sort_y0[sort_d+1]<=y0[4];
            sort_r0[sort_d+1]<=r0[4];
            
            sort_x0[sort_e+1]<=x0[5];
            sort_y0[sort_e+1]<=y0[5];
            sort_r0[sort_e+1]<=r0[5];
        end
		else begin
            sort_x0[0]<=sort_x0[0];
            sort_y0[0]<=sort_y0[0];
            sort_r0[0]<=sort_r0[0];
        end
    end
end

//opt for acc a1
always@(posedge clk or posedge reset)begin
	if(reset)begin
	    opt<=0;
	end
	else begin
		if(cs==OP_sort) begin
			opt<=0;
		end
		else if(cs==OP_heron2) begin
			opt<=0;
		end
		else if(cs==OP_vector2) begin
            opt<=1;
        end
		else begin
			opt<=opt;
		end
	end
end

//acc data in
always@(posedge clk or posedge reset)begin
	if(reset)begin
		acc_a<=0;
		acc_b<=0;
		acc_c<=0;
		acc_d<=0;
	end
	else begin
		if(cs==OP_sort) begin
			case(sort_cnt)
				0		:begin
							acc_a<=vector_x0[0];
							acc_b<=vector_y0[1];
							acc_c<=vector_x0[1];
							acc_d<=vector_y0[0];
						end
				1   	:begin
							acc_a<=vector_x0[0];
							acc_b<=vector_y0[2];
							acc_c<=vector_x0[2];
							acc_d<=vector_y0[0];
						end
				2   	:begin
							acc_a<=vector_x0[0];
							acc_b<=vector_y0[3];
							acc_c<=vector_x0[3];
							acc_d<=vector_y0[0];
						end
				3		:begin
							acc_a<=vector_x0[0];
							acc_b<=vector_y0[4];
							acc_c<=vector_x0[4];
							acc_d<=vector_y0[0];
						end
				4   	:begin
							acc_a<=vector_x0[1];
							acc_b<=vector_y0[2];
							acc_c<=vector_x0[2];
							acc_d<=vector_y0[1];
						end
				5   	:begin
							acc_a<=vector_x0[1];
							acc_b<=vector_y0[3];
							acc_c<=vector_x0[3];
							acc_d<=vector_y0[1];
						end
				6		:begin
							acc_a<=vector_x0[1];
							acc_b<=vector_y0[4];
							acc_c<=vector_x0[4];
							acc_d<=vector_y0[1];
						end
				7		:begin
							acc_a<=vector_x0[2];
							acc_b<=vector_y0[3];
							acc_c<=vector_x0[3];
							acc_d<=vector_y0[2];
						end
				8		:begin
							acc_a<=vector_x0[2];
							acc_b<=vector_y0[4];
							acc_c<=vector_x0[4];
							acc_d<=vector_y0[2];
						end
				9		:begin
							acc_a<=vector_x0[3];
							acc_b<=vector_y0[4];
							acc_c<=vector_x0[4];
							acc_d<=vector_y0[3];
						end
				default	:begin
							acc_a<=acc_a;
							acc_b<=acc_b;
							acc_c<=acc_c;
							acc_d<=acc_d;
						end
			endcase
		end
		else if(cs==OP_heron2) begin
			if(tri_cnt==5) begin
				acc_a<=sort_x0[5];
				acc_b<=sort_y0[0];
				acc_c<=sort_x0[0];
				acc_d<=sort_y0[5];
			end
			else begin
				acc_a<=sort_x0[tri_cnt];
				acc_b<=sort_y0[tri_cnt+1];
				acc_c<=sort_x0[tri_cnt+1];
				acc_d<=sort_y0[tri_cnt];
			end
		end
		else if(cs==OP_heron1) begin
            acc_a<=vector_x0[heron_cnt-1];
            acc_b<=vector_x0[heron_cnt-1];
            acc_c<=vector_y0[heron_cnt-1];
            acc_d<=vector_y0[heron_cnt-1];
        end
		else begin
			acc_a<=acc_a;
			acc_b<=acc_b;
			acc_c<=acc_c;
			acc_d<=acc_d;
		end
	end
end


always@(posedge clk or posedge reset)begin
	if(reset)begin
		mul_a<=0;
		mul_b<=0;
		mul_c<=0;
		mul_d<=0;
	end
	else begin
		if(cs==OP_heron2) begin
            mul_a<=tri_s[tri_cnt-1];
            mul_b<=(tri_s[tri_cnt-1]+(~(tri_a[tri_cnt-1]))+1);
            mul_c<=(tri_s[tri_cnt-1]+(~(tri_b[tri_cnt-1]))+1);
            mul_d<=(tri_s[tri_cnt-1]+(~(tri_c[tri_cnt-1]))+1);
        end
		else begin
			mul_a<=mul_a;
            mul_b<=mul_b;
            mul_c<=mul_c;
            mul_d<=mul_d;
		end
	end
end


//triangle s,a,b,c
always@(posedge clk or posedge reset) begin
    if(reset) begin
        tri_a[0]<=0;
        tri_b[0]<=0;
        tri_c[0]<=0;
    end
	else begin
        if(cs==OP_heron1) begin
            tri_s[0]<=((tri_a[0]+tri_b[0]+tri_c[0])>>1);
            tri_s[1]<=((tri_a[1]+tri_b[1]+tri_c[1])>>1);
            tri_s[2]<=((tri_a[2]+tri_b[2]+tri_c[2])>>1);
            tri_s[3]<=((tri_a[3]+tri_b[3]+tri_c[3])>>1);
            tri_s[4]<=((tri_a[4]+tri_b[4]+tri_c[4])>>1);
            tri_s[5]<=((tri_a[5]+tri_b[5]+tri_c[5])>>1);
            
            tri_a[heron_cnt-3]<=sqrt_o;
            
            tri_b[0]<=sort_r0[0];
            tri_c[0]<=sort_r0[1];
            
            tri_b[1]<=sort_r0[1];
            tri_c[1]<=sort_r0[2];
            
            tri_b[2]<=sort_r0[2];
            tri_c[2]<=sort_r0[3];
            
            tri_b[3]<=sort_r0[3];
            tri_c[3]<=sort_r0[4];
            
            tri_b[4]<=sort_r0[4];
            tri_c[4]<=sort_r0[5];
            
            tri_b[5]<=sort_r0[5];
            tri_c[5]<=sort_r0[0];
        end
		else begin
		    tri_s[0]<=tri_s[0];
            tri_a[0]<=tri_a[0];
            tri_b[0]<=tri_b[0];
            tri_c[0]<=tri_c[0];
        end
    end
end


//area calculate
always@(posedge clk or posedge reset) begin
    if(reset) begin
        area_of6<=0;
        area_of7<=0;
    end
	else begin
        if(cs==OP_heron2) begin
            if(tri_cnt>=1 && tri_cnt<=6) begin
                area_of6<=area_of6+acc_out;
            end
            if(tri_cnt>=3 && tri_cnt<=8) begin
                area_of7<=area_of7+sqrt_o*sqrt_o2;
            end
        end
        else if(cs==OP_input) begin
           area_of6<=0;
           area_of7<=0;
        end
		else begin
            area_of6<=area_of6;
            area_of7<=area_of7;
        end
    end
end
wire [20:0] fin_of6t;
assign fin_of6t=area_of6>>1;
assign fin_of6=((~(fin_of6t))+1);
assign fin_of7=area_of7;

always@(posedge clk or posedge reset) begin
    if(reset) begin
        sqrt_o<=0;
        sqrt_o2<=0;
    end
	else begin
        if(cs==OP_heron1) begin
            sqrt_o<=sqrt(acc_out);
            sqrt_o2<=sqrt_o2;
        end
        else if(cs==OP_heron2) begin
            sqrt_o<=sqrt(mul_out);
            sqrt_o2<=sqrt(mul_out2);
        end
		else begin
            sqrt_o<=sqrt_o;
            sqrt_o2<=sqrt_o2;
        end
    end
end

always@(posedge clk or posedge reset) begin
    if(reset) begin
        valid<=0;
        is_inside<=0;
    end
	else begin
        if(cs==OP_output) begin
            valid<=1;
            is_inside<=(fin_of6 >= fin_of7) ? 1 : 0;
        end
		else begin
            valid<=0;
            is_inside<=0;
        end
    end
end

//Verilog function to find square root of a 22 bit number.      The output is 11 bit.
function [10:0] sqrt;
    input [21:0] num;  //declare input
    //intermediate signals.
    reg [21:0] a;
    reg [10:0] q;
    reg [17:0] left,right,r;
    integer i;
    begin //initialize all the variables.
        a = num;
        q = 0;
        i = 0;
        left = 0;   //input to adder/sub
        right = 0;  //input to adder/sub
        r = 0;  //remainder
        //run the calculations for 11 iterations.
        for(i=0;i<11;i=i+1) begin 
            right = {q,r[17],1'b1};
            left = {r[15:0],a[21:20]};
            a = {a[19:0],2'b00};    //left shift by 2 bits.
            if (r[17] == 1) //add if r is negative
                r = left + right;
            else    //subtract if r is positive
                r = left - right;
            q = {q[9:0],!r[17]};       
        end
        sqrt = q;   //final assignment of output.
    end
endfunction

endmodule 

module mul(i_a,i_b,o_answer);
	input [10:0] i_a,i_b;
	output [21:0] o_answer;

	assign o_answer=i_a*i_b;
endmodule 

module acc(i_a,i_b,i_c,i_d,opt,o_answer);
	input [10:0] i_a,i_b,i_c,i_d;
	input opt;
	output [21:0] o_answer;
	wire [21:0] add_a,add_b;

	assign add_a={{11{i_a[10]}},i_a}*{{11{i_b[10]}},i_b};
	assign add_b={{11{i_c[10]}},i_c}*{{11{i_d[10]}},i_d};

	assign o_answer=(opt==1) ? add_a+add_b : add_a+(~(add_b))+1;
endmodule 