module peach_sprite(
    input [9:0] x,
    input [9:0] y,
    input active_pixels,
    input [9:0] peach_x_pos,  // virtual grid x
    input [9:0] peach_y_pos,  // virtual grid y
    input [1:0] direction,    // up > down > left > right
    input [1:0] anim_frame,   // toggles frame 1 and frame 2
    output reg [23:0] color
);

    // convert virtual coordinates to physical coordinates
    wire [9:0] peach_left = {peach_x_pos[7:0], 2'b00};
    wire [9:0] peach_top  = {peach_y_pos[7:0], 2'b00};

    // checks if drawing inside peach
    wire inside_peach = active_pixels &&
                        (x >= peach_left) && (x < peach_left + 10'd32) &&
                        (y >= peach_top)  && (y < peach_top  + 10'd32);

    wire [4:0] offset_x = x - peach_left;
    wire [4:0] offset_y = y - peach_top;
    wire [3:0] sprite_x = offset_x[4:1];
    wire [3:0] sprite_y = offset_y[4:1];

    wire [3:0] rot_x = 4'd15 - sprite_y;
    wire [3:0] rot_y = sprite_x;

    // mirrors depending on which way peach is facing
    wire [3:0] mirrored_x = (direction == 2'b10) ? (4'd15 - rot_x) : rot_x;

    // each row is 16 pixels, 1 hex digit per pixel
    // 0 = transparent
    // 1 = crown and brooch (light yellow)
    // 2 = jewel, eyes, earrings (cyan)
    // 3 = collar and dark dress (hot pink)
    // 4 = hair (gold)
    // 5 = skin
    // 6 = dress (light pink)
    reg [63:0] row_pixels;

    always @(*) begin
        case (rot_y)
            4'd0:  row_pixels = 64'h0000001010100000;
            4'd1:  row_pixels = 64'h0000002131200000;
            4'd2:  row_pixels = 64'h0000044444440000;
            4'd3:  row_pixels = 64'h0000444444444000;
            4'd4:  row_pixels = 64'h0044444444444400;
            4'd5:  row_pixels = 64'h0004444544544400;
            4'd6:  row_pixels = 64'h0000454255254000;
            4'd7:  row_pixels = 64'h0004424555554400;
            4'd8:  row_pixels = 64'h0444446331364440;
            4'd9:  row_pixels = 64'h0044466612166400;
            4'd10: row_pixels = 64'h0444446666664400;
            4'd11: row_pixels = 64'h0444440333304400;
            4'd12: row_pixels = anim_frame[0] ? 64'h0044433336334400 : 64'h0044443336334400;
            4'd13: row_pixels = anim_frame[0] ? 64'h0004333366334000 : 64'h0004466366633600;
            4'd14: row_pixels = anim_frame[0] ? 64'h0066666666660000 : 64'h0000666666666600;
            4'd15: row_pixels = anim_frame[0] ? 64'h0033333333330000 : 64'h0000333333333300;
            default: row_pixels = 64'h0000000000000000;
        endcase
    end

    wire [3:0] pixel_code = row_pixels[(4'd15 - mirrored_x) * 4 +: 4];

    always @(*) begin
        if (!inside_peach) begin
            color = 24'h000000;
        end else begin
            case (pixel_code)
                4'd1: color = 24'hFFFE88; // crown / brooch yellow
                4'd2: color = 24'h56BDF7; // eyes / jewels / earring blue
                4'd3: color = 24'hEB33B9; // hot pink collar & trim
                4'd4: color = 24'hFBE35D; // golden hair
                4'd5: color = 24'hFBE6BB; // skin
                4'd6: color = 24'hF4B5FB; // light pink dress
                default: color = 24'h000000;
            endcase
        end
    end

endmodule