module life_display(
    input [9:0] x,
    input [9:0] y,
    input active_pixels,
    input [9:0] heart_x_pos,
    input [9:0] heart_y_pos,
    output reg [23:0] color
);

    parameter DARK_RED  = 24'hAA0000;
    parameter RED       = 24'hFF0000;
    parameter LIGHT_RED = 24'hFF4444;
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

    reg [15:0] dark_red_row_bits;
    reg [15:0] red_row_bits;
    reg [15:0] light_red_row_bits;
    reg [15:0] white_row_bits;

    always @(*) begin
        dark_red_row_bits  = 16'b0000000000000000;
        red_row_bits       = 16'b0000000000000000;
        light_red_row_bits = 16'b0000000000000000;
        white_row_bits     = 16'b0000000000000000;

        case (py)
            4'd0: begin
                red_row_bits       = 16'b0011100000000000;
                light_red_row_bits = 16'b0000000000011100;
            end
            4'd1: begin
                red_row_bits       = 16'b0111110000000000;
                light_red_row_bits = 16'b0000000000110010;
                white_row_bits     = 16'b0000000000001100;
            end
            4'd2: begin
                dark_red_row_bits  = 16'b1000000000000000;
                red_row_bits       = 16'b0111111001111000;
                white_row_bits     = 16'b0000000000000100;
                light_red_row_bits = 16'b0000000000000011;
            end
            4'd3: begin
                dark_red_row_bits  = 16'b1000000000000000;
                red_row_bits       = 16'b0111111111111100;
                white_row_bits     = 16'b0000000000000010;
                light_red_row_bits = 16'b0000000000000001;
            end
            4'd4: begin
                dark_red_row_bits  = 16'b1100000000000000;
                red_row_bits       = 16'b0011111111111100;
                light_red_row_bits = 16'b0000000000000011;
            end
            4'd5: begin
                dark_red_row_bits  = 16'b1100000000000000;
                red_row_bits       = 16'b0011111111111110;
                light_red_row_bits = 16'b0000000000000001;
            end
            4'd6: begin
                dark_red_row_bits  = 16'b1100000000000000;
                red_row_bits       = 16'b0011111111111110;
                light_red_row_bits = 16'b0000000000000001;
            end
            4'd7: begin
                dark_red_row_bits  = 16'b1100000000000000;
                red_row_bits       = 16'b0011111111111110;
                light_red_row_bits = 16'b0000000000000001;
            end
            4'd8: begin
                dark_red_row_bits  = 16'b0110000000000000;
                red_row_bits       = 16'b0001111111111110;
            end
            4'd9: begin
                dark_red_row_bits  = 16'b0011000000000000;
                red_row_bits       = 16'b0000111111111100;
            end
            4'd10: begin
                dark_red_row_bits  = 16'b0001100000000000;
                red_row_bits       = 16'b0000011111111000;
            end
            4'd11: begin
                dark_red_row_bits  = 16'b0000110000000000;
                red_row_bits       = 16'b0000001111110000;
            end
            4'd12: begin
                dark_red_row_bits  = 16'b0000011000000000;
                red_row_bits       = 16'b0000000111100000;
            end
            4'd13: begin
                dark_red_row_bits  = 16'b0000001100000000;
                red_row_bits       = 16'b0000000011000000;
            end
            4'd14: begin
                dark_red_row_bits  = 16'b0000000100000000;
                red_row_bits       = 16'b0000000010000000;
            end
        endcase

        if (!inside_heart)
            color = BLACK;
        else if (white_row_bits[bit_index])
            color = WHITE;
        else if (light_red_row_bits[bit_index])
            color = LIGHT_RED;
        else if (dark_red_row_bits[bit_index])
            color = DARK_RED;
        else if (red_row_bits[bit_index])
            color = RED;
        else
            color = BLACK;
    end

endmodule