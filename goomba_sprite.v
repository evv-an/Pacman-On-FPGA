module goomba_sprite(
    input [9:0] x,
    input [9:0] y,
    input active_pixels,
    input [9:0] goomba_x_pos, //virtual grid x
    input [9:0] goomba_y_pos, //virtual grid y
    input [1:0] anim_frame,
    output reg [23:0] color
);

    parameter BROWN = 24'h8B3A10;
    parameter DARK_BROWN = 24'h2A1004;
    parameter TAN = 24'hF8C490;
    parameter WHITE = 24'hFFFFFF;
    parameter EYE_BLACK = 24'h010101;
    parameter BLACK = 24'h000000;

    //convert virtual coordinates to physical coordinates
    wire [9:0] goomba_left = {goomba_x_pos[7:0], 2'b00};
    wire [9:0] goomba_top = {goomba_y_pos[7:0], 2'b00};

    //checks if drawing inside goomba
    wire inside_goomba = active_pixels && (x >= goomba_left) && (x < goomba_left + 10'd32) && (y >= goomba_top) && (y < goomba_top + 10'd32);

    wire [4:0] offset_x = x - goomba_left;
    wire [4:0] offset_y = y - goomba_top;
    wire [3:0] sprite_x = offset_x[4:1];
    wire [3:0] sprite_y = offset_y[4:1];

    //rotate coordinates 90 degrees ccw
    wire [3:0] rotated_x = 4'd15 - sprite_y;
    wire [3:0] rotated_y = sprite_x;
    wire [3:0] bit_index = 4'd15 - rotated_x;

    reg [15:0] brown_row_bits;
    reg [15:0] dark_brown_row_bits;
    reg [15:0] tan_row_bits;
    reg [15:0] white_row_bits;
    reg [15:0] eye_row_bits;

    always @(*) begin
        brown_row_bits = 16'b0000000000000000;
        dark_brown_row_bits = 16'b0000000000000000;
        tan_row_bits = 16'b0000000000000000;
        white_row_bits = 16'b0000000000000000;
        eye_row_bits = 16'b0000000000000000;

        case (rotated_y)
            4'd0: begin
                brown_row_bits = 16'b0000011111110000;
            end
            4'd1: begin
                brown_row_bits = 16'b0000111111111000;
            end
            4'd2: begin
                brown_row_bits = 16'b0000011111111000;
                dark_brown_row_bits = 16'b0001100000000110;
            end
            4'd3: begin
                brown_row_bits = 16'b0011100111110100;
                dark_brown_row_bits = 16'b0000011000001000;
            end
            4'd4: begin
                brown_row_bits = 16'b0011111001001110;
                dark_brown_row_bits = 16'b0000000110110000;
            end
            4'd5: begin
                brown_row_bits = 16'b0011110011100110;
                eye_row_bits = 16'b0000001100011000;
            end
            4'd6: begin
                brown_row_bits = 16'b0111110011100110;
                eye_row_bits = 16'b0000001100011000;
            end
            4'd7: begin
                brown_row_bits = 16'b0111001111111000;
                white_row_bits = 16'b0000110000000110;
            end
            4'd8: begin
                brown_row_bits = 16'b1111001111111001;
                white_row_bits = 16'b0000110000000110;
            end
            4'd9: begin
                brown_row_bits = 16'b1111111111111111;
            end
            4'd10: begin
                brown_row_bits = 16'b0111111111111110;
            end
            4'd11: begin
                tan_row_bits = 16'b0000111111111000;
            end
            4'd12: begin
                tan_row_bits = 16'b0000111111111000;
            end
            4'd13: begin
                brown_row_bits = (anim_frame[0] == 1'b0) ? 16'b0001111000111100 : 16'b0001111001111000;
            end
            4'd14: begin
                brown_row_bits = (anim_frame[0] == 1'b0) ? 16'b0011111000111110 : 16'b0001111101111100;
            end
            4'd15: begin
                brown_row_bits = (anim_frame[0] == 1'b0) ? 16'b0011111000111110 : 16'b0001111101111100;
            end
        endcase

        if (!inside_goomba)
            color = BLACK;
        else if (eye_row_bits[bit_index])
            color = EYE_BLACK;
        else if (white_row_bits[bit_index])
            color = WHITE;
        else if (dark_brown_row_bits[bit_index])
            color = DARK_BROWN;
        else if (brown_row_bits[bit_index])
            color = BROWN;
        else if (tan_row_bits[bit_index])
            color = TAN;
        else
            color = BLACK;
        end

endmodule