module life_display(input [2:0]draw_x,
    input [2:0]draw_y,
	 output reg [23:0]color);

parameter DARK_RED  = 24'hAA0000;
parameter RED       = 24'hFF0000;
parameter LIGHT_RED = 24'hFF4444;
parameter WHITE     = 24'hFFFFFF;
parameter BLACK     = 24'h000000;

//rotates art
wire [2:0] px = 3'd7 - draw_y;
wire [2:0] py = draw_x;

always @(*) begin
     case ({py, px})
            // row by row pixel coloring
            {3'd0, 3'd1}, {3'd0, 3'd2}: color = RED;
            {3'd0, 3'd5}, {3'd0, 3'd6}: color = LIGHT_RED;

            {3'd1, 3'd0}:               color = DARK_RED;
            {3'd1, 3'd1}, {3'd1, 3'd2},
            {3'd1, 3'd3}, {3'd1, 3'd4},
            {3'd1, 3'd5}:               color = RED;
            {3'd1, 3'd6}:               color = WHITE;
            {3'd1, 3'd7}:               color = LIGHT_RED;

            {3'd2, 3'd0}, {3'd2, 3'd1}: color = DARK_RED;
            {3'd2, 3'd2}, {3'd2, 3'd3},
            {3'd2, 3'd4}, {3'd2, 3'd5},
            {3'd2, 3'd6}:               color = RED;
            {3'd2, 3'd7}:               color = LIGHT_RED;

            {3'd3, 3'd1}, {3'd3, 3'd2}: color = DARK_RED;
            {3'd3, 3'd3}, {3'd3, 3'd4},
            {3'd3, 3'd5}, {3'd3, 3'd6}: color = RED;

            {3'd4, 3'd2}, {3'd4, 3'd3}: color = DARK_RED;
            {3'd4, 3'd4}, {3'd4, 3'd5}: color = RED;

            {3'd5, 3'd3}:               color = DARK_RED;
            {3'd5, 3'd4}:               color = RED;

            default:                    color = BLACK;
        endcase
    end

endmodule