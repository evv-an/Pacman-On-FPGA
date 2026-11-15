module scared_ghost_sprite(
    input [9:0] x,
    input [9:0] y,
    input active_pixels,
    input [9:0] ghost_x_pos, //virtual grid x
    input [9:0] ghost_y_pos, //virtual grid y
    input [1:0] anim_frame,
    input flash,             //flash near timer run out
    output reg [23:0] color
);

    parameter BLUE  = 24'h0000FF;
    parameter WHITE = 24'hFFFFFF;
    parameter RED   = 24'hFF0000;
    parameter BLACK = 24'h000000;

    //flashes white and red near end of frightened timer
    wire [23:0] body_color = flash ? WHITE : BLUE;
    wire [23:0] face_color = flash ? RED   : WHITE;

    //convert virtual coordinates to physical coordinates
    wire [9:0] ghost_left = {ghost_x_pos[7:0], 2'b00};
    wire [9:0] ghost_top  = {ghost_y_pos[7:0], 2'b00};

    //checks if drawing inside scared ghost
    wire inside_ghost = active_pixels && (x >= ghost_left) && (x < ghost_left + 10'd32) && (y >= ghost_top) && (y < ghost_top + 10'd32);

    wire [4:0] offset_x = x - ghost_left;
    wire [4:0] offset_y = y - ghost_top;
    wire [3:0] sprite_x = offset_x[4:1];
    wire [3:0] sprite_y = offset_y[4:1];

    //rotate coordinates 90 degrees ccw
    wire [3:0] rotated_x = 4'd15 - sprite_y;
    wire [3:0] rotated_y = sprite_x;
    wire [3:0] bit_index = 4'd15 - rotated_x;

    reg [15:0] body_row_bits;
    reg [15:0] face_row_bits;

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
            4'd14: body_row_bits = (anim_frame[0] == 1'b0) ? 16'b1111001111001111 : 16'b1111001111001111;
            4'd15: body_row_bits = (anim_frame[0] == 1'b0) ? 16'b0110000110000110 : 16'b1111001111001111;
            default: body_row_bits = 16'b0000000000000000;
        endcase

        case (rotated_y)
            4'd6:  face_row_bits = 16'b0000011001100000;
            4'd7:  face_row_bits = 16'b0000011001100000;
            4'd11: face_row_bits = 16'b0001100110011000;
            4'd12: face_row_bits = 16'b0010011001100100;
            default: face_row_bits = 16'b0000000000000000;
        endcase

        if (!inside_ghost)
            color = BLACK;
        else if (face_row_bits[bit_index])
            color = face_color;
        else if (body_row_bits[bit_index])
            color = body_color;
        else
            color = BLACK;
    end

endmodule