module mario_sprite(
    input [9:0] x,
    input [9:0] y,
    input active_pixels,
    input [9:0] mario_x_pos, //virtual grid x
    input [9:0] mario_y_pos, //virtual grid y
    input [1:0] direction, //up > down > left > right
    output reg [23:0] color
);

    parameter RED = 24'hFF0000;
    parameter BLUE = 24'h2255FF;
    parameter YELLOW = 24'hFFFF00;
    parameter BROWN = 24'h7A3610;
    parameter SKIN = 24'hFFC88C;
    parameter EYE_BLACK = 24'h010101;
    parameter BLACK = 24'h000000;

    //convert virtual coordinates to physical coordinates
    wire [9:0] mario_left = {mario_x_pos[7:0], 2'b00};
    wire [9:0] mario_top = {mario_y_pos[7:0], 2'b00};

    //checks if drawing inside mario
    wire inside_mario = active_pixels && (x >= mario_left) && (x < mario_left + 10'd32) && (y >= mario_top) && (y < mario_top + 10'd32);

    wire [4:0] offset_x = x - mario_left;
    wire [4:0] offset_y = y - mario_top;
    wire [3:0] sprite_x = offset_x[4:1];
    wire [3:0] sprite_y = offset_y[4:1];

    //rotate coordinates 90 degrees ccw and mirror when facing left
    wire [3:0] rotated_x = (direction == 2'b10) ? sprite_y : (4'd15 - sprite_y);
    wire [3:0] rotated_y = sprite_x;
    wire [3:0] bit_index = 4'd15 - rotated_x;

    reg [15:0] red_row_bits;
    reg [15:0] blue_row_bits;
    reg [15:0] yellow_row_bits;
    reg [15:0] brown_row_bits;
    reg [15:0] skin_row_bits;
    reg [15:0] eye_row_bits;

    always @(*) begin
        red_row_bits = 16'b0000000000000000;
        blue_row_bits = 16'b0000000000000000;
        yellow_row_bits = 16'b0000000000000000;
        brown_row_bits = 16'b0000000000000000;
        skin_row_bits = 16'b0000000000000000;
        eye_row_bits = 16'b0000000000000000;

        case (rotated_y)
            4'd0: begin
                red_row_bits = 16'b0000111111000000;
            end
            4'd1: begin
                red_row_bits = 16'b0001111111111000;
            end
            4'd2: begin
                brown_row_bits = 16'b0001111000000000;
                skin_row_bits = 16'b0000000110100000;
                eye_row_bits = 16'b0000000001000000;
            end
            4'd3: begin
                brown_row_bits = 16'b0011010000000000;
                skin_row_bits = 16'b0000101110111000;
                eye_row_bits = 16'b0000000001000000;
            end
            4'd4: begin
                brown_row_bits = 16'b0011011000100000;
                skin_row_bits = 16'b0000100111011100;
            end
            4'd5: begin
                brown_row_bits = 16'b0011100001111000;
                skin_row_bits = 16'b0000011110000000;
            end
            4'd6: begin
                skin_row_bits = 16'b0000111111110000;
            end
            4'd7: begin
                blue_row_bits = 16'b0001110111000000;
                red_row_bits = 16'b0000001000000000;
            end
            4'd8: begin
                blue_row_bits = 16'b0011110110111000;
                red_row_bits = 16'b0000001001000000;
            end
            4'd9: begin
                blue_row_bits = 16'b0111110000111100;
                red_row_bits = 16'b0000001111000000;
            end
            4'd10: begin
                skin_row_bits = 16'b0110000000001100;
                blue_row_bits = 16'b0001100000010000;
                red_row_bits = 16'b0000010110100000;
                yellow_row_bits = 16'b0000001001000000;
            end
            4'd11: begin
                skin_row_bits = 16'b0111000000011100;
                red_row_bits = 16'b0000111111100000;
            end
            4'd12: begin
                skin_row_bits = 16'b0110000000001100;
                red_row_bits = 16'b0000111111100000;
            end
            4'd13: begin
                red_row_bits = 16'b0001111011110000;
            end
            4'd14: begin
                brown_row_bits = 16'b0011110001111000;
            end
            4'd15: begin
                brown_row_bits = 16'b0111110001111100;
            end
        endcase

        if (!inside_mario)
            color = BLACK;
        else if (eye_row_bits[bit_index])
            color = EYE_BLACK;
        else if (yellow_row_bits[bit_index])
            color = YELLOW;
        else if (red_row_bits[bit_index])
            color = RED;
        else if (blue_row_bits[bit_index])
            color = BLUE;
        else if (brown_row_bits[bit_index])
            color = BROWN;
        else if (skin_row_bits[bit_index])
            color = SKIN;
        else
            color = BLACK;
    end

endmodule