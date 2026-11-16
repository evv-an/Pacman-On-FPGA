module three_decimal_vals_w_neg(input [14:0]pellets,
	input [14:0]largepellets, 
	input [14:0]ghosts,
	output [6:0]HEX43,
	output [6:0]HEX33,
	output [6:0]HEX23,
	output [6:0]HEX13,
	output [6:0]HEX03);


wire [14:0]val;
assign val = ((pellets * 15'd10) + (largepellets * 15'd50) + ghosts);

wire [6:0]seg7_tenthousands1;
wire [6:0]seg7_thousands1;
wire [6:0]seg7_hundreds1;
wire [6:0]seg7_tens1;
wire [6:0]seg7_ones1;

assign HEX43 = seg7_tenthousands1;
assign HEX33 = seg7_thousands1;
assign HEX23 = seg7_hundreds1; 
assign HEX13 = seg7_tens1; 
assign HEX03 = seg7_ones1; 

reg [3:0] result_tenthous_digit;
reg [3:0] result_thous_digit;
reg [3:0] result_hunds_digit;
reg [3:0] result_tens_digit;
reg [3:0] result_ones_digit;



always @(*)
begin
	result_ones_digit = 15'd0;
	result_tens_digit = (((val % 15'd10000) % 15'd1000) % 15'd100) / 15'd10;
	result_hunds_digit = ((val % 15'd10000) % 15'd1000) / 15'd100;
	result_thous_digit = (val % 15'd10000) / 15'd1000;
	result_tenthous_digit = val / 15'd10000;
end

seven_segment my_seven_segment_ones(result_ones_digit, seg7_ones1);
seven_segment my_seven_segment_tens(result_tens_digit, seg7_tens1);
seven_segment my_seven_segment_hundreds(result_hunds_digit, seg7_hundreds1);
seven_segment my_seven_segment_thousands(result_thous_digit, seg7_thousands1);
seven_segment my_seven_segment_tenthousands(result_tenthous_digit, seg7_tenthousands1);

endmodule