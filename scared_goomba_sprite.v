module scared_goomba_sprite(
    input [9:0] x,
    input [9:0] y,
    input active_pixels,
    input [9:0] goomba_x_pos, //virtual grid x
    input [9:0] goomba_y_pos, //virtual grid y
    input [1:0] anim_frame,
    input flash,              //flash near timer run out
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
    wire [9:0] goomba_left = {goomba_x_pos[7:0], 2'b00};
    wire [9:0] goomba_top  = {goomba_y_pos[7:0], 2'b00};

    //checks if drawing inside scared goomba
    wire inside_goomba = active_pixels && (x >= goomba_left) && (x < goomba_left + 10'd32) && (y >= goomba_top) && (y < goomba_top + 10'd32);

    wire [4:0] offset_x = x - goomba_left;
    wire [4:0] offset_y = y - goomba_top;
    wire [3:0] sprite_x = offset_x[4:1];
    wire [3:0] sprite_y = offset_y[4:1];

    //rotate coordinates 90 degrees ccw
    wire [3:0] rotated_x = 4'd15 - sprite_y;
    wire [3:0] rotated_y = sprite_x;
    wire [3:0] bit_index = 4'd15 - rotated_x;

    reg [15:0] body_row_bits;
    reg [15:0] face_row_bits;

    always @(*) begin
        body_row_bits = 16'b0000000000000000;
        face_row_bits = 16'b0000000000000000;

        case (rotated_y)
            4'd0:  body_row_bits = 16'b0000011111110000;
            4'd1:  body_row_bits = 16'b0000111111111000;
            4'd2:  body_row_bits = 16'b0001111111111000;
            4'd3: begin
                body_row_bits = 16'b0011100011100100;
                face_row_bits = 16'b0000011100011000;
            end
            4'd4:  body_row_bits = 16'b0011111111111110;
            4'd5: begin
                body_row_bits = 16'b0011110011100110;
                face_row_bits = 16'b0000001100011000;
            end
            4'd6: begin
                body_row_bits = 16'b0111110011100110;
                face_row_bits = 16'b0000001100011000;
            end
            4'd7: begin
                body_row_bits = 16'b0111001111111000;
                face_row_bits = 16'b0000110000000110;
            end
            4'd8: begin
                body_row_bits = 16'b1111001111111001;
                face_row_bits = 16'b0000110000000110;
            end
            4'd9:  body_row_bits = 16'b1111111111111111;
            4'd10: body_row_bits = 16'b0111111111111110;
            4'd11: begin
                body_row_bits = 16'b0111000000000110;
                face_row_bits = 16'b0000111111111000;
            end
            4'd12: face_row_bits = 16'b0000111111111000;
            4'd13: body_row_bits = (anim_frame[0] == 1'b0) ? 16'b0001111000111100 : 16'b0001111001111000;
            4'd14: body_row_bits = (anim_frame[0] == 1'b0) ? 16'b0011111000111110 : 16'b0001111101111100;
            4'd15: body_row_bits = (anim_frame[0] == 1'b0) ? 16'b0011111000111110 : 16'b0001111101111100;
        endcase

        if (!inside_goomba)
            color = BLACK;
        else if (face_row_bits[bit_index])
            color = face_color;
        else if (body_row_bits[bit_index])
            color = body_color;
        else
            color = BLACK;
    end

endmodule