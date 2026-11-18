module scared_shy_guy_sprite(
    input [9:0] x,
    input [9:0] y,
    input active_pixels,
    input [9:0] shy_guy_x_pos, // virtual grid x
    input [9:0] shy_guy_y_pos, // virtual grid y
    input [1:0] anim_frame,    // cycles 0, 1, 2
    input flash,               // blinks near end of frightened timer
    output reg [23:0] color
);

    // convert virtual coordinates to physical coordinates
    wire [9:0] shy_guy_left = {shy_guy_x_pos[7:0], 2'b00};
    wire [9:0] shy_guy_top  = {shy_guy_y_pos[7:0], 2'b00};

    // checks if drawing inside shy guy
    wire inside_shy_guy = active_pixels &&
                          (x >= shy_guy_left) && (x < shy_guy_left + 10'd32) &&
                          (y >= shy_guy_top)  && (y < shy_guy_top  + 10'd32);

    wire [4:0] offset_x = x - shy_guy_left;
    wire [4:0] offset_y = y - shy_guy_top;
    wire [3:0] sprite_x = offset_x[4:1];
    wire [3:0] sprite_y = offset_y[4:1];

    // rotate coordinates 90 degrees ccw (same as shy_guy_sprite)
    wire [3:0] rot_x = 4'd15 - sprite_y;
    wire [3:0] rot_y = sprite_x;

    // each row is 16 pixels, 1 hex digit per pixel
    // 0 = transparent
    // 1 = outline, eyes, mouth (white, red when flashing)
    // 2 = body and mask (blue, white when flashing)
    reg [63:0] row_pixels;

    always @(*) begin
        case (rot_y)
            4'd0:  row_pixels = 64'h0000111111110000;
            4'd1:  row_pixels = 64'h0011222221111000;
            4'd2:  row_pixels = 64'h0122222112222100;
            4'd3:  row_pixels = 64'h1222222122222210;
            4'd4:  row_pixels = 64'h0122221122222211;
            4'd5:  row_pixels = 64'h0011111222122121;
            4'd6:  row_pixels = 64'h0111111221121121;
            4'd7:  row_pixels = 64'h0122221122222221;
            4'd8:  row_pixels = 64'h0122222122111211;
            4'd9:  row_pixels = 64'h0012222112222210;
            4'd10: row_pixels = 64'h0121112211222121;
            4'd11: row_pixels = 64'h1222211122111221;
            4'd12: case (anim_frame)
                       2'd1:    row_pixels = 64'h1122222112222111;
                       2'd2:    row_pixels = 64'h0112222112222111;
                       default: row_pixels = 64'h1112222112222111;
                   endcase
            4'd13: case (anim_frame)
                       2'd1:    row_pixels = 64'h0112211001222100;
                       2'd2:    row_pixels = 64'h0001122100112210;
                       default: row_pixels = 64'h0011221101122210;
                   endcase
            4'd14: case (anim_frame)
                       2'd1:    row_pixels = 64'h0001110001111100;
                       2'd2:    row_pixels = 64'h0000111000011110;
                       default: row_pixels = 64'h0001111000111100;
                   endcase
            default: row_pixels = 64'h0000000000000000;
        endcase
    end

    wire [3:0] pixel_code = row_pixels[(4'd15 - rot_x) * 4 +: 4];

    always @(*) begin
        if (!inside_shy_guy) begin
            color = 24'h000000;
        end else begin
            case (pixel_code)
                4'd1: color = flash ? 24'hEC4A57 : 24'hFFFFFF; // outline, eyes, mouth
                4'd2: color = flash ? 24'hFFFFFF : 24'h1C23EE; // body and mask
                default: color = 24'h000000;
            endcase
        end
    end

endmodule