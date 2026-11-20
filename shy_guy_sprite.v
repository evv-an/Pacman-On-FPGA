module shy_guy_sprite(
    input [9:0] x,
    input [9:0] y,
    input active_pixels,
    input [9:0] shy_guy_x_pos,
    input [9:0] shy_guy_y_pos,
    input [1:0] anim_frame,
    output reg [23:0] color
);

    parameter OUTLINE = 24'h2C2D31;
    parameter RED     = 24'hEC4A57;
    parameter WHITE   = 24'hFFFFFF;
    parameter GRAY    = 24'hBEC0BF;
    parameter YELLOW  = 24'hFEF99D;
    parameter BROWN   = 24'h803A2E;
    parameter BLACK   = 24'h000000;

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
    reg [15:0] red_row_bits;
    reg [15:0] white_row_bits;
    reg [15:0] gray_row_bits;
    reg [15:0] yellow_row_bits;
    reg [15:0] brown_row_bits;

    always @(*) begin
        outline_row_bits = 16'b0000000000000000;
        red_row_bits     = 16'b0000000000000000;
        white_row_bits   = 16'b0000000000000000;
        gray_row_bits    = 16'b0000000000000000;
        yellow_row_bits  = 16'b0000000000000000;
        brown_row_bits   = 16'b0000000000000000;

        case (rot_y)
            4'd0: begin
                outline_row_bits = 16'b0000111111110000;
            end
            4'd1: begin
                outline_row_bits = 16'b0011000001111000;
                red_row_bits     = 16'b0000111110000000;
            end
            4'd2: begin
                outline_row_bits = 16'b0100000110000100;
                red_row_bits     = 16'b0011111000000000;
                white_row_bits   = 16'b0000000001100000;
                gray_row_bits    = 16'b0000000000011000;
            end
            4'd3: begin
                outline_row_bits = 16'b1000000100000010;
                red_row_bits     = 16'b0111111000000000;
                white_row_bits   = 16'b0000000011110000;
                gray_row_bits    = 16'b0000000000001100;
            end
            4'd4: begin
                outline_row_bits = 16'b0100001100000011;
                red_row_bits     = 16'b0011110000000000;
                white_row_bits   = 16'b0000000011110000;
                gray_row_bits    = 16'b0000000000001100;
            end
            4'd5: begin
                outline_row_bits = 16'b0011111001101101;
                white_row_bits   = 16'b0000000110010000;
                gray_row_bits    = 16'b0000000000000010;
            end
            4'd6: begin
                outline_row_bits = 16'b0111111001101101;
                white_row_bits   = 16'b0000000110010000;
                gray_row_bits    = 16'b0000000000000010;
            end
            4'd7: begin
                outline_row_bits = 16'b0100001100000001;
                red_row_bits     = 16'b0011110000000000;
                white_row_bits   = 16'b0000000011111000;
                gray_row_bits    = 16'b0000000000000110;
            end
            4'd8: begin
                outline_row_bits = 16'b0100000100010011;
                red_row_bits     = 16'b0011111000000000;
                white_row_bits   = 16'b0000000011101000;
                gray_row_bits    = 16'b0000000000000100;
            end
            4'd9: begin
                outline_row_bits = 16'b0010000110010010;
                red_row_bits     = 16'b0001111000000000;
                white_row_bits   = 16'b0000000001100000;
                gray_row_bits    = 16'b0000000000001100;
            end
            4'd10: begin
                outline_row_bits = 16'b0101110011000101;
                red_row_bits     = 16'b0010001100000000;
                white_row_bits   = 16'b0000000000100000;
                gray_row_bits    = 16'b0000000000011000;
                brown_row_bits   = 16'b0000000000000010;
            end
            4'd11: begin
                outline_row_bits = 16'b1000011100111001;
                red_row_bits     = 16'b0111100000000100;
                yellow_row_bits  = 16'b0000000011000000;
                brown_row_bits   = 16'b0000000000000010;
            end
            4'd12: case (anim_frame)
                2'd1: begin
                    outline_row_bits = 16'b1100000110000111;
                    red_row_bits     = 16'b0000000001111000;
                    brown_row_bits   = 16'b0011111000000000;
                end
                2'd2: begin
                    outline_row_bits = 16'b0110000110000111;
                    red_row_bits     = 16'b0000000001111000;
                    brown_row_bits   = 16'b0001111000000000;
                end
                default: begin
                    outline_row_bits = 16'b1110000110000111;
                    red_row_bits     = 16'b0000000001111000;
                    brown_row_bits   = 16'b0001111000000000;
                end
            endcase
            4'd13: case (anim_frame)
                2'd1: begin
                    outline_row_bits = 16'b0110011001000100;
                    brown_row_bits   = 16'b0001100000111000;
                end
                2'd2: begin
                    outline_row_bits = 16'b0001100100110010;
                    brown_row_bits   = 16'b0000011000001100;
                end
                default: begin
                    outline_row_bits = 16'b0011001101100010;
                    brown_row_bits   = 16'b0000110000011100;
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
            color = OUTLINE;
        else if (red_row_bits[bit_index])
            color = RED;
        else if (white_row_bits[bit_index])
            color = WHITE;
        else if (gray_row_bits[bit_index])
            color = GRAY;
        else if (yellow_row_bits[bit_index])
            color = YELLOW;
        else if (brown_row_bits[bit_index])
            color = BROWN;
        else
            color = BLACK;
    end

endmodule