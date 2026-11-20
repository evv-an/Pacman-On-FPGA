module peach_sprite(
    input [9:0] x,
    input [9:0] y,
    input active_pixels,
    input [9:0] peach_x_pos,
    input [9:0] peach_y_pos,
    input [1:0] direction,
    input [1:0] anim_frame,
    output reg [23:0] color
);

    parameter YELLOW    = 24'hFFFE88;
    parameter BLUE      = 24'h56BDF7;
    parameter PINK_TRIM = 24'hEB33B9;
    parameter HAIR      = 24'hFBE35D;
    parameter SKIN      = 24'hFBE6BB;
    parameter DRESS     = 24'hF4B5FB;
    parameter BLACK     = 24'h000000;

    wire [9:0] peach_left = {peach_x_pos[7:0], 2'b00};
    wire [9:0] peach_top  = {peach_y_pos[7:0], 2'b00};

    wire inside_peach = active_pixels &&
                        (x >= peach_left) && (x < peach_left + 10'd32) &&
                        (y >= peach_top)  && (y < peach_top  + 10'd32);

    wire [4:0] offset_x = x - peach_left;
    wire [4:0] offset_y = y - peach_top;
    wire [3:0] sprite_x = offset_x[4:1];
    wire [3:0] sprite_y = offset_y[4:1];

    wire [3:0] rot_x = 4'd15 - sprite_y;
    wire [3:0] rot_y = sprite_x;

    wire [3:0] mirrored_x = (direction == 2'b01) ? (4'd15 - rot_x) : rot_x;
    wire [3:0] bit_index  = 4'd15 - mirrored_x;

    reg [15:0] yellow_row_bits;
    reg [15:0] blue_row_bits;
    reg [15:0] pink_trim_row_bits;
    reg [15:0] hair_row_bits;
    reg [15:0] skin_row_bits;
    reg [15:0] dress_row_bits;

    always @(*) begin
        yellow_row_bits    = 16'b0000000000000000;
        blue_row_bits      = 16'b0000000000000000;
        pink_trim_row_bits = 16'b0000000000000000;
        hair_row_bits      = 16'b0000000000000000;
        skin_row_bits      = 16'b0000000000000000;
        dress_row_bits     = 16'b0000000000000000;

        case (rot_y)
            4'd0: begin
                yellow_row_bits    = 16'b0000001010100000;
            end
            4'd1: begin
                yellow_row_bits    = 16'b0000000101000000;
                blue_row_bits      = 16'b0000001000100000;
                pink_trim_row_bits = 16'b0000000010000000;
            end
            4'd2: begin
                hair_row_bits      = 16'b0000011111110000;
            end
            4'd3: begin
                hair_row_bits      = 16'b0000111111111000;
            end
            4'd4: begin
                hair_row_bits      = 16'b0011111111111100;
            end
            4'd5: begin
                hair_row_bits      = 16'b0001111011011100;
                skin_row_bits      = 16'b0000000100100000;
            end
            4'd6: begin
                blue_row_bits      = 16'b0000000100100000;
                hair_row_bits      = 16'b0000101000001000;
                skin_row_bits      = 16'b0000010011010000;
            end
            4'd7: begin
                blue_row_bits      = 16'b0000010000000000;
                hair_row_bits      = 16'b0001101000001100;
                skin_row_bits      = 16'b0000000111110000;
            end
            4'd8: begin
                yellow_row_bits    = 16'b0000000001000000;
                pink_trim_row_bits = 16'b0000000110100000;
                hair_row_bits      = 16'b0111110000001110;
                dress_row_bits     = 16'b0000001000010000;
            end
            4'd9: begin
                yellow_row_bits    = 16'b0000000010100000;
                blue_row_bits      = 16'b0000000001000000;
                hair_row_bits      = 16'b0011100000000100;
                dress_row_bits     = 16'b0000011100011000;
            end
            4'd10: begin
                hair_row_bits      = 16'b0111110000001100;
                dress_row_bits     = 16'b0000001111110000;
            end
            4'd11: begin
                pink_trim_row_bits = 16'b0000000111100000;
                hair_row_bits      = 16'b0111110000001100;
            end
            4'd12: begin
                pink_trim_row_bits = anim_frame[0] ? 16'b0000011110110000 : 16'b0000001110110000;
                hair_row_bits      = anim_frame[0] ? 16'b0011100000001100 : 16'b0011110000001100;
                dress_row_bits     = 16'b0000000001000000;
            end
            4'd13: begin
                pink_trim_row_bits = anim_frame[0] ? 16'b0000111100110000 : 16'b0000000100011000;
                hair_row_bits      = anim_frame[0] ? 16'b0001000000001000 : 16'b0001100000000000;
                dress_row_bits     = anim_frame[0] ? 16'b0000000011000000 : 16'b0000011011100100;
            end
            4'd14: begin
                dress_row_bits     = anim_frame[0] ? 16'b0011111111110000 : 16'b0000111111111100;
            end
            4'd15: begin
                pink_trim_row_bits = anim_frame[0] ? 16'b0011111111110000 : 16'b0000111111111100;
            end
        endcase

        if (!inside_peach)
            color = BLACK;
        else if (yellow_row_bits[bit_index])
            color = YELLOW;
        else if (blue_row_bits[bit_index])
            color = BLUE;
        else if (pink_trim_row_bits[bit_index])
            color = PINK_TRIM;
        else if (hair_row_bits[bit_index])
            color = HAIR;
        else if (skin_row_bits[bit_index])
            color = SKIN;
        else if (dress_row_bits[bit_index])
            color = DRESS;
        else
            color = BLACK;
    end

endmodule