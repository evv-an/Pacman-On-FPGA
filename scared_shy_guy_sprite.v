module scared_shy_guy_sprite(
    input [9:0] x,
    input [9:0] y,
    input active_pixels,
    input [9:0] shy_guy_x_pos,
    input [9:0] shy_guy_y_pos,
    input [1:0] anim_frame,
    input flash,
    output reg [23:0] color
);

    parameter BLUE  = 24'h1C23EE;
    parameter WHITE = 24'hFFFFFF;
    parameter BLACK = 24'h000000;

    wire [23:0] outline_color = flash ? BLUE  : WHITE;
    wire [23:0] body_color    = flash ? WHITE : BLUE;

    wire [9:0] shy_guy_left = {shy_guy_x_pos[7:0], 2'b00};
    wire [9:0] shy_guy_top  = {shy_guy_y_pos[7:0], 2'b00};

    wire inside_shy_guy = active_pixels &&
                          (x >= shy_guy_left) && (x < shy_guy_left + 10'd32) &&
                          (y >= shy_guy_top)  && (y < shy_guy_top  + 10'd32);

    wire [4:0] offset_x = x - shy_guy_left;
    wire [4:0] offset_y = y - shy_guy_top;
    wire [3:0] sprite_x = offset_x[4:1];
    wire [3:0] sprite_y = offset_y[4:1];

    wire [3:0] rot_x     = 4'd15 - sprite_y;
    wire [3:0] rot_y     = sprite_x;
    wire [3:0] bit_index = 4'd15 - rot_x;

    reg [15:0] outline_row_bits;
    reg [15:0] body_row_bits;

    always @(*) begin
        outline_row_bits = 16'b0000000000000000;
        body_row_bits    = 16'b0000000000000000;

        case (rot_y)
            4'd0: begin
                outline_row_bits = 16'b0000111111110000;
            end
            4'd1: begin
                outline_row_bits = 16'b0011000001111000;
                body_row_bits    = 16'b0000111110000000;
            end
            4'd2: begin
                outline_row_bits = 16'b0100000110000100;
                body_row_bits    = 16'b0011111001111000;
            end
            4'd3: begin
                outline_row_bits = 16'b1000000100000010;
                body_row_bits    = 16'b0111111011111100;
            end
            4'd4: begin
                outline_row_bits = 16'b0100001100000011;
                body_row_bits    = 16'b0011110011111100;
            end
            4'd5: begin
                outline_row_bits = 16'b0011111000100101;
                body_row_bits    = 16'b0000000111011010;
            end
            4'd6: begin
                outline_row_bits = 16'b0111111001101101;
                body_row_bits    = 16'b0000000110010010;
            end
            4'd7: begin
                outline_row_bits = 16'b0100001100000001;
                body_row_bits    = 16'b0011110011111110;
            end
            4'd8: begin
                outline_row_bits = 16'b0100000100111011;
                body_row_bits    = 16'b0011111011000100;
            end
            4'd9: begin
                outline_row_bits = 16'b0010000110000010;
                body_row_bits    = 16'b0001111001111100;
            end
            4'd10: begin
                outline_row_bits = 16'b0101110011000101;
                body_row_bits    = 16'b0010001100111010;
            end
            4'd11: begin
                outline_row_bits = 16'b1000011100111001;
                body_row_bits    = 16'b0111100011000110;
            end
            4'd12: case (anim_frame)
                2'd1: begin
                    outline_row_bits = 16'b1100000110000111;
                    body_row_bits    = 16'b0011111001111000;
                end
                2'd2: begin
                    outline_row_bits = 16'b0110000110000111;
                    body_row_bits    = 16'b0001111001111000;
                end
                default: begin
                    outline_row_bits = 16'b1110000110000111;
                    body_row_bits    = 16'b0001111001111000;
                end
            endcase
            4'd13: case (anim_frame)
                2'd1: begin
                    outline_row_bits = 16'b0110011001000100;
                    body_row_bits    = 16'b0001100000111000;
                end
                2'd2: begin
                    outline_row_bits = 16'b0001100100110010;
                    body_row_bits    = 16'b0000011000001100;
                end
                default: begin
                    outline_row_bits = 16'b0011001101100010;
                    body_row_bits    = 16'b0000110000011100;
                end
            endcase
            4'd14: case (anim_frame)
                2'd1:    outline_row_bits = 16'b0001110001111100;
                2'd2:    outline_row_bits = 16'b0000111000011110;
                default: outline_row_bits = 16'b0001111000111100;
            endcase
        endcase

        if (!inside_shy_guy)
            color = BLACK;
        else if (outline_row_bits[bit_index])
            color = outline_color;
        else if (body_row_bits[bit_index])
            color = body_color;
        else
            color = BLACK;
    end

endmodule