module shy_guy_sprite(
    input [9:0] x,
    input [9:0] y,
    input active_pixels,
    input [9:0] shy_guy_x_pos, // virtual grid x
    input [9:0] shy_guy_y_pos, // virtual grid y
    input [1:0] anim_frame,    // cycles 0, 1, 2
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

    // rotate coordinates 90 degrees ccw
    wire [3:0] rot_x = 4'd15 - sprite_y;
    wire [3:0] rot_y = sprite_x;

    // each row is 16 pixels, 1 hex digit per pixel
    // 0 = transparent
    // 1 = outline, eyes, mouth (dark gray)
    // 2 = robe (red)
    // 3 = mask (white)
    // 4 = mask shading (gray)
    // 5 = belt buckle (yellow)
    // 6 = shoes (brown)
    reg [63:0] row_pixels;

    always @(*) begin
        case (rot_y)
            4'd0:  row_pixels = 64'h0000111111110000;
            4'd1:  row_pixels = 64'h0011222221111000;
            4'd2:  row_pixels = 64'h0122222113344100;
            4'd3:  row_pixels = 64'h1222222133334410;
            4'd4:  row_pixels = 64'h0122221133334411;
            4'd5:  row_pixels = 64'h0011111331131141;
            4'd6:  row_pixels = 64'h0111111331131141;
            4'd7:  row_pixels = 64'h0122221133333441;
            4'd8:  row_pixels = 64'h0122222133313411;
            4'd9:  row_pixels = 64'h0012222113314410;
            4'd10: row_pixels = 64'h0121112211344161;
            4'd11: row_pixels = 64'h1222211155111261;
            4'd12: case (anim_frame)
                       2'd1:    row_pixels = 64'h1166666112222111;
                       2'd2:    row_pixels = 64'h0116666112222111;
                       default: row_pixels = 64'h1116666112222111;
                   endcase
            4'd13: case (anim_frame)
                       2'd1:    row_pixels = 64'h0116611001666100;
                       2'd2:    row_pixels = 64'h0001166100116610;
                       default: row_pixels = 64'h0011661101166610;
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
                4'd1: color = 24'h2C2D31; // outline, eyes, mouth
                4'd2: color = 24'hEC4A57; // red robe
                4'd3: color = 24'hFFFFFF; // white mask
                4'd4: color = 24'hBEC0BF; // gray mask shading
                4'd5: color = 24'hFEF99D; // yellow belt buckle
                4'd6: color = 24'h803A2E; // brown shoes
                default: color = 24'h000000;
            endcase
        end
    end

endmodule