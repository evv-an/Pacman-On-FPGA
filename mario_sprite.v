module mario_sprite(
    input [9:0] x,
    input [9:0] y,
    input active_pixels,
    input [9:0] mario_x_pos, // virtual grid x
    input [9:0] mario_y_pos, // virtual grid y
    input [1:0] direction,   // up > down > left > right
    input [1:0] anim_frame,  // toggles frame 1 and frame 2
    output reg [23:0] color
);

    // convert virtual coordinates to physical coordinates
    wire [9:0] mario_left = {mario_x_pos[7:0], 2'b00};
    wire [9:0] mario_top  = {mario_y_pos[7:0], 2'b00};

    // checks if drawing inside mario
    wire inside_mario = active_pixels &&
                        (x >= mario_left) && (x < mario_left + 10'd32) &&
                        (y >= mario_top)  && (y < mario_top  + 10'd32);

    wire [4:0] offset_x = x - mario_left;
    wire [4:0] offset_y = y - mario_top;
    wire [3:0] sprite_x = offset_x[4:1];
    wire [3:0] sprite_y = offset_y[4:1];

    // rotate coordinates 90 degrees ccw, mirror when facing left
    wire [3:0] rotated_x = (direction == 2'b01) ? sprite_y : (4'd15 - sprite_y);
    wire [3:0] rotated_y = sprite_x;

    // each row is 16 pixels, 1 hex digit per pixel
    // 0 = transparent
    // 1 = cap and shirt (red)
    // 2 = overalls (blue)
    // 3 = buttons (yellow)
    // 4 = hair, mustache, boots (brown)
    // 5 = skin
    // 6 = eyes (black)
    reg [63:0] row_pixels;

    always @(*) begin
        case (rotated_y)
            4'd0:  row_pixels = 64'h0000011111000000;
            4'd1:  row_pixels = 64'h0000111111100000;
            4'd2:  row_pixels = 64'h0001111111111000;
            4'd3:  row_pixels = 64'h0011115555500000;
            4'd4:  row_pixels = 64'h0011455556500000;
            4'd5:  row_pixels = 64'h0045445556555000;
            4'd6:  row_pixels = 64'h0045445445555000;
            4'd7:  row_pixels = 64'h0004455544440000;
            4'd8:  row_pixels = 64'h0000555555500000;
            4'd9:  row_pixels = 64'h0000012111000000;
            4'd10: row_pixels = 64'h0000112111200000;
            4'd11: row_pixels = 64'h0001155311550000;
            4'd12: row_pixels = 64'h0001555222550000;
            4'd13: row_pixels = anim_frame[0] ? 64'h0004552222224400 : 64'h0000552222200000;
            4'd14: row_pixels = anim_frame[0] ? 64'h0044422222244400 : 64'h0000442222440000;
            4'd15: row_pixels = anim_frame[0] ? 64'h0444222000044000 : 64'h0000444000444000;
            default: row_pixels = 64'h0000000000000000;
        endcase
    end

    wire [3:0] pixel_code = row_pixels[(4'd15 - rotated_x) * 4 +: 4];

    always @(*) begin
        if (!inside_mario) begin
            color = 24'h000000;
        end else begin
            case (pixel_code)
                4'd1: color = 24'hDD362D; // red cap and shirt
                4'd2: color = 24'h2255FF; // blue overalls
                4'd3: color = 24'hFFFF00; // yellow buttons
                4'd4: color = 24'h7A3610; // brown hair, mustache, boots
                4'd5: color = 24'hFFC88C; // skin
                4'd6: color = 24'h010101; // black eyes
                default: color = 24'h000000;
            endcase
        end
    end

endmodule