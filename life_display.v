module life_display(
    input [9:0] x,
    input [9:0] y,
    input active_pixels,
    input [9:0] heart_x_pos,
    input [9:0] heart_y_pos,
    output reg [23:0] color
);

 
    parameter RED       = 24'hFF0000;
    parameter WHITE     = 24'hFFFFFF;
    parameter BLACK     = 24'h000000;

    //16x15 art rotated 90 degrees ccw and scaled 2x (30 wide, 32 tall)
    wire inside_heart = active_pixels &&
                        (x >= heart_x_pos) && (x < heart_x_pos + 10'd30) &&
                        (y >= heart_y_pos) && (y < heart_y_pos + 10'd32);

    wire [4:0] offset_x = x - heart_x_pos;
    wire [4:0] offset_y = y - heart_y_pos;
    wire [3:0] sprite_x = offset_x[4:1];
    wire [3:0] sprite_y = offset_y[4:1];

    wire [3:0] px = 4'd15 - sprite_y;
    wire [3:0] py = sprite_x;
    wire [3:0] bit_index = 4'd15 - px;

    reg [15:0] red_row_bits;
    reg [15:0] white_row_bits;

    always @(*) begin
        red_row_bits       = 16'b0000000000000000;
        white_row_bits     = 16'b0000000000000000;

        case (py)
            4'd6: red_row_bits       = 16'b0011110000111100;
            
            4'd7: begin
                red_row_bits       = 16'b0111111001100110;
                white_row_bits     = 16'b0000000000011000;
            end
            4'd8: begin
                red_row_bits       = 16'b1111111111111011;
                white_row_bits     = 16'b0000000000000100;
            end
            4'd9: red_row_bits       = 16'b1111111111111111;
            4'd10: red_row_bits       = 16'b0111111111111110;
            4'd11: red_row_bits      = 16'b0001111111111000;
            4'd12: red_row_bits      = 16'b0000111111110000;
            4'd13: red_row_bits      = 16'b0000001111000000;
            4'd14: red_row_bits      = 16'b0000000110000000;
        endcase

        if (!inside_heart)
            color = BLACK;
        else if (white_row_bits[bit_index])
            color = WHITE;
        else if (red_row_bits[bit_index])
            color = RED;
        else
            color = BLACK;
    end

endmodule