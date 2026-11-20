module mario_sprite(
    input [9:0] x,
    input [9:0] y,
    input active_pixels,
    input [9:0] mario_x_pos,
    input [9:0] mario_y_pos,
    input [1:0] direction,
    input [1:0] anim_frame,
    output reg [23:0] color
);

    parameter RED       = 24'hDD362D;
    parameter BLUE      = 24'h2255FF;
    parameter YELLOW    = 24'hFFFF00;
    parameter BROWN     = 24'h7A3610;
    parameter SKIN      = 24'hFFC88C;
    parameter EYE_BLACK = 24'h010101;
    parameter BLACK     = 24'h000000;

    wire [9:0] mario_left = {mario_x_pos[7:0], 2'b00};
    wire [9:0] mario_top  = {mario_y_pos[7:0], 2'b00};

    wire inside_mario = active_pixels &&
                        (x >= mario_left) && (x < mario_left + 10'd32) &&
                        (y >= mario_top)  && (y < mario_top  + 10'd32);

    wire [4:0] offset_x = x - mario_left;
    wire [4:0] offset_y = y - mario_top;
    wire [3:0] sprite_x = offset_x[4:1];
    wire [3:0] sprite_y = offset_y[4:1];

    wire [3:0] rotated_x = (direction == 2'b01) ? sprite_y : (4'd15 - sprite_y);
    wire [3:0] rotated_y = sprite_x;
    wire [3:0] bit_index = 4'd15 - rotated_x;

    reg [15:0] red_row_bits;
    reg [15:0] blue_row_bits;
    reg [15:0] yellow_row_bits;
    reg [15:0] brown_row_bits;
    reg [15:0] skin_row_bits;
    reg [15:0] eye_row_bits;

    always @(*) begin
        red_row_bits    = 16'b0000000000000000;
        blue_row_bits   = 16'b0000000000000000;
        yellow_row_bits = 16'b0000000000000000;
        brown_row_bits  = 16'b0000000000000000;
        skin_row_bits   = 16'b0000000000000000;
        eye_row_bits    = 16'b0000000000000000;

        case (rotated_y)
            4'd0: begin
                red_row_bits    = 16'b0000011111000000;
            end
            4'd1: begin
                red_row_bits    = 16'b0000111111100000;
            end
            4'd2: begin
                red_row_bits    = 16'b0001111111111000;
            end
            4'd3: begin
                red_row_bits    = 16'b0011110000000000;
                skin_row_bits   = 16'b0000001111100000;
            end
            4'd4: begin
                red_row_bits    = 16'b0011000000000000;
                brown_row_bits  = 16'b0000100000000000;
                skin_row_bits   = 16'b0000011110100000;
                eye_row_bits    = 16'b0000000001000000;
            end
            4'd5: begin
                brown_row_bits  = 16'b0010110000000000;
                skin_row_bits   = 16'b0001001110111000;
                eye_row_bits    = 16'b0000000001000000;
            end
            4'd6: begin
                brown_row_bits  = 16'b0010110110000000;
                skin_row_bits   = 16'b0001001001111000;
            end
            4'd7: begin
                brown_row_bits  = 16'b0001100011110000;
                skin_row_bits   = 16'b0000011100000000;
            end
            4'd8: begin
                skin_row_bits   = 16'b0000111111100000;
            end
            4'd9: begin
                red_row_bits    = 16'b0000010111000000;
                blue_row_bits   = 16'b0000001000000000;
            end
            4'd10: begin
                red_row_bits    = 16'b0000110111000000;
                blue_row_bits   = 16'b0000001000100000;
            end
            4'd11: begin
                red_row_bits    = 16'b0001100011000000;
                yellow_row_bits = 16'b0000000100000000;
                skin_row_bits   = 16'b0000011000110000;
            end
            4'd12: begin
                red_row_bits    = 16'b0001000000000000;
                blue_row_bits   = 16'b0000000111000000;
                skin_row_bits   = 16'b0000111000110000;
            end
            4'd13: begin
                blue_row_bits   = anim_frame[0] ? 16'b0000001111110000 : 16'b0000001111100000;
                brown_row_bits  = anim_frame[0] ? 16'b0001000000001100 : 16'b0000000000000000;
                skin_row_bits   = 16'b0000110000000000;
            end
            4'd14: begin
                blue_row_bits   = anim_frame[0] ? 16'b0000011111100000 : 16'b0000001111000000;
                brown_row_bits  = anim_frame[0] ? 16'b0011100000011100 : 16'b0000110000110000;
            end
            4'd15: begin
                blue_row_bits   = anim_frame[0] ? 16'b0000111000000000 : 16'b0000000000000000;
                brown_row_bits  = anim_frame[0] ? 16'b0111000000011000 : 16'b0000111000111000;
            end
        endcase

        if (!inside_mario)
            color = BLACK;
        else if (red_row_bits[bit_index])
            color = RED;
        else if (blue_row_bits[bit_index])
            color = BLUE;
        else if (yellow_row_bits[bit_index])
            color = YELLOW;
        else if (brown_row_bits[bit_index])
            color = BROWN;
        else if (skin_row_bits[bit_index])
            color = SKIN;
        else if (eye_row_bits[bit_index])
            color = EYE_BLACK;
        else
            color = BLACK;
    end

endmodule