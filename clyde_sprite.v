module clyde_sprite(
    input [9:0] x,
    input [9:0] y,
    input active_pixels,
    input [9:0] clyde_x_pos, //virtual grid x
    input [9:0] clyde_y_pos, //virtual grid y
    input [1:0] direction, //up > down > left > right
    input [1:0] anim_frame,
    output reg [23:0] color
);

    parameter ORANGE = 24'hFFB852;
    parameter WHITE = 24'hFFFFFF;
    parameter BLUE = 24'h0000FF;
    parameter BLACK = 24'h000000;

    //convert virtual coordinates to physical coordinates
    wire [9:0] clyde_left = {clyde_x_pos[7:0], 2'b00};
    wire [9:0] clyde_top = {clyde_y_pos[7:0], 2'b00};

    //checks if drawing inside clyde
    wire inside_clyde = active_pixels && (x >= clyde_left) && (x < clyde_left + 10'd32) && (y >= clyde_top) && (y < clyde_top + 10'd32);

    wire [4:0] offset_x = x - clyde_left;
    wire [4:0] offset_y = y - clyde_top;
    wire [3:0] sprite_x = offset_x[4:1];
    wire [3:0] sprite_y = offset_y[4:1];

    //rotate coordinates 90 degrees ccw
    wire [3:0] rotated_x = 4'd15 - sprite_y;
    wire [3:0] rotated_y = sprite_x;
    wire [3:0] bit_index = 4'd15 - rotated_x;

    reg [15:0] body_row_bits;
    reg [15:0] eye_white_row_bits;
    reg [15:0] pupil_blue_row_bits;

    always @(*) begin
        case (rotated_y)
            4'd0: body_row_bits = 16'b0000011111100000;
            4'd1: body_row_bits = 16'b0001111111111000;
            4'd2: body_row_bits = 16'b0011111111111100;
            4'd3: body_row_bits = 16'b0111111111111110;
            4'd4: body_row_bits = 16'b0111111111111110;
            4'd5: body_row_bits = 16'b1111111111111111;
            4'd6: body_row_bits = 16'b1111111111111111;
            4'd7: body_row_bits = 16'b1111111111111111;
            4'd8: body_row_bits = 16'b1111111111111111;
            4'd9: body_row_bits = 16'b1111111111111111;
            4'd10: body_row_bits = 16'b1111111111111111;
            4'd11: body_row_bits = 16'b1111111111111111;
            4'd12: body_row_bits = 16'b1111111111111111;
            4'd13: body_row_bits = 16'b1111111111111111;
            4'd14: body_row_bits = (anim_frame[0] == 1'b0) ? 16'b1111001111001111 : 16'b1001111001111001;
            4'd15: body_row_bits = (anim_frame[0] == 1'b0) ? 16'b0110000110000110 : 16'b0000110000110000;
            default: body_row_bits = 16'b0000000000000000;
        endcase

        case (rotated_y)
            4'd5: eye_white_row_bits = 16'b0000110000110000;
            4'd6: eye_white_row_bits = 16'b0001111001111000;
            4'd7: eye_white_row_bits = 16'b0001111001111000;
            4'd8: eye_white_row_bits = 16'b0001111001111000;
            4'd9: eye_white_row_bits = 16'b0000000000000000;
            default: eye_white_row_bits = 16'b0000000000000000;
        endcase

        pupil_blue_row_bits = 16'b0000000000000000;
        case (direction)
            2'b00: begin //up
                case (rotated_y)
                    4'd5: pupil_blue_row_bits = 16'b0000110000110000;
                    4'd6: pupil_blue_row_bits = 16'b0000110000110000;
                endcase
            end
            2'b01: begin //down
                case (rotated_y)
                    4'd7: pupil_blue_row_bits = 16'b0000110000110000;
                    4'd8: pupil_blue_row_bits = 16'b0000110000110000;
                endcase
            end
            2'b10: begin //left
                case (rotated_y)
                    4'd6: pupil_blue_row_bits = 16'b0001100001100000;
                    4'd7: pupil_blue_row_bits = 16'b0001100001100000;
                endcase
            end
            2'b11: begin //right
                case (rotated_y)
                    4'd6: pupil_blue_row_bits = 16'b0000011000011000;
                    4'd7: pupil_blue_row_bits = 16'b0000011000011000;
                endcase
            end
        endcase

        if (!inside_clyde)
            color = BLACK;
        else if (pupil_blue_row_bits[bit_index])
            color = BLUE;
        else if (eye_white_row_bits[bit_index])
            color = WHITE;
        else if (body_row_bits[bit_index])
            color = ORANGE;
        else
            color = BLACK;
    end

endmodule