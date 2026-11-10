module mario_sprite(
    input [2:0] draw_x,
    input [2:0] draw_y,
    input [1:0] direction,
    output reg [23:0] color
);
parameter RED    = 24'hFF0000;
parameter BLUE   = 24'h2255FF;
parameter YELLOW = 24'hFFFF00;
parameter BROWN  = 24'h7A3610;
parameter SKIN   = 24'hFFC88C;
parameter WHITE  = 24'hFFFFFF;
parameter BLACK  = 24'h000000;

// rotates 90 degrees ccw
wire [2:0] py = draw_x;
wire [2:0] px = (direction == 2'b10) ? draw_y : (3'd7 - draw_y);

always @(*) begin
    case ({py, px})
        {3'd0, 3'd3}, {3'd0, 3'd4}, {3'd0, 3'd5}: color = RED;
        {3'd0, 3'd6}: color = WHITE;
        {3'd1, 3'd3}, {3'd1, 3'd4}, {3'd1, 3'd5}, {3'd1, 3'd6}, {3'd1, 3'd7}: color = RED;
        {3'd2, 3'd2}: color = BROWN;
        {3'd2, 3'd3}: color = SKIN;
        {3'd2, 3'd4}: color = BROWN;
        {3'd2, 3'd5}: color = BLACK;
        {3'd2, 3'd6}: color = SKIN;
        {3'd3, 3'd2}: color = BROWN;
        {3'd3, 3'd3}, {3'd3, 3'd4}: color = SKIN;
        {3'd3, 3'd5}, {3'd3, 3'd6}: color = BROWN;
        {3'd3, 3'd7}: color = SKIN;
        {3'd4, 3'd3}: color = BROWN;
        {3'd4, 3'd4}, {3'd4, 3'd5}, {3'd4, 3'd6}: color = SKIN;
        {3'd5, 3'd1}, {3'd5, 3'd2}: color = RED;
        {3'd5, 3'd3}: color = YELLOW;
        {3'd5, 3'd4}, {3'd5, 3'd5}: color = BLUE;
        {3'd5, 3'd6}: color = YELLOW;
        {3'd6, 3'd0}, {3'd6, 3'd7}: color = WHITE;
        {3'd6, 3'd2}, {3'd6, 3'd3}, {3'd6, 3'd4}, {3'd6, 3'd5}, {3'd6, 3'd6}: color = BLUE;
        {3'd7, 3'd2}, {3'd7, 3'd6}: color = BROWN;
        default: color = BLACK;
    endcase
end
endmodule