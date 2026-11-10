module game_won_text(
    input [4:0] tile_x_idx,
    input [3:0] tile_y_idx,
    input [2:0] draw_x,
    input [2:0] draw_y,
    input game_won_active,
    output reg [23:0] color
);

parameter WHITE = 24'hFFFFFF;
parameter BLACK = 24'h000000;

// where to draw text
wire in_game_won_zone = (tile_x_idx == 5'd11) && (tile_y_idx >= 4'd4 && tile_y_idx <= 4'd10);
wire [5:0] rel_x = (4'd10 - tile_y_idx) * 4'd8 + (3'd7 - draw_y);

// pixel mapping within row
wire [2:0] rel_y = draw_x;
reg [2:0] char_x;
reg [2:0] char_id;

always @(*) begin
    if (rel_x >= 6'd9 && rel_x <= 6'd13) begin
        char_id = 3'd0; char_x = rel_x - 6'd9;   // Y
    end else if (rel_x >= 6'd15 && rel_x <= 6'd19) begin
        char_id = 3'd1; char_x = rel_x - 6'd15;  // O
    end else if (rel_x >= 6'd21 && rel_x <= 6'd25) begin
        char_id = 3'd2; char_x = rel_x - 6'd21;  // U
    end else if (rel_x >= 6'd29 && rel_x <= 6'd33) begin
        char_id = 3'd3; char_x = rel_x - 6'd29;  // W
    end else if (rel_x >= 6'd35 && rel_x <= 6'd39) begin
        char_id = 3'd1; char_x = rel_x - 6'd35;  // O
    end else if (rel_x >= 6'd41 && rel_x <= 6'd45) begin
        char_id = 3'd4; char_x = rel_x - 6'd41;  // N
    end else begin
        char_id = 3'd5; char_x = 3'd0;           // space
    end
end

reg [4:0] row_pixels;
always @(*) begin
    case ({char_id, rel_y})
        // y
        {3'd0, 3'd0}: row_pixels = 5'b10001;
        {3'd0, 3'd1}: row_pixels = 5'b10001;
        {3'd0, 3'd2}: row_pixels = 5'b01010;
        {3'd0, 3'd3}: row_pixels = 5'b00100;
        {3'd0, 3'd4}: row_pixels = 5'b00100;
        {3'd0, 3'd5}: row_pixels = 5'b00100;
        {3'd0, 3'd6}: row_pixels = 5'b00100;

        // o
        {3'd1, 3'd0}: row_pixels = 5'b01110;
        {3'd1, 3'd1}: row_pixels = 5'b10001;
        {3'd1, 3'd2}: row_pixels = 5'b10001;
        {3'd1, 3'd3}: row_pixels = 5'b10001;
        {3'd1, 3'd4}: row_pixels = 5'b10001;
        {3'd1, 3'd5}: row_pixels = 5'b10001;
        {3'd1, 3'd6}: row_pixels = 5'b01110;

        // u
        {3'd2, 3'd0}: row_pixels = 5'b10001;
        {3'd2, 3'd1}: row_pixels = 5'b10001;
        {3'd2, 3'd2}: row_pixels = 5'b10001;
        {3'd2, 3'd3}: row_pixels = 5'b10001;
        {3'd2, 3'd4}: row_pixels = 5'b10001;
        {3'd2, 3'd5}: row_pixels = 5'b10001;
        {3'd2, 3'd6}: row_pixels = 5'b01110;

        // w
        {3'd3, 3'd0}: row_pixels = 5'b10001;
        {3'd3, 3'd1}: row_pixels = 5'b10001;
        {3'd3, 3'd2}: row_pixels = 5'b10001;
        {3'd3, 3'd3}: row_pixels = 5'b10101;
        {3'd3, 3'd4}: row_pixels = 5'b10101;
        {3'd3, 3'd5}: row_pixels = 5'b11011;
        {3'd3, 3'd6}: row_pixels = 5'b10001;

        // n
        {3'd4, 3'd0}: row_pixels = 5'b10001;
        {3'd4, 3'd1}: row_pixels = 5'b11001;
        {3'd4, 3'd2}: row_pixels = 5'b10101;
        {3'd4, 3'd3}: row_pixels = 5'b10101;
        {3'd4, 3'd4}: row_pixels = 5'b10011;
        {3'd4, 3'd5}: row_pixels = 5'b10001;
        {3'd4, 3'd6}: row_pixels = 5'b10001;

        default: row_pixels = 5'b00000;
    endcase

    if (game_won_active && in_game_won_zone && row_pixels[3'd4 - char_x])
        color = WHITE;
    else
        color = BLACK;
end
endmodule