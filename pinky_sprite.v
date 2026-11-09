module pinky_sprite(input [2:0] draw_x, input [2:0] draw_y, input [1:0] direction, input [1:0] anim_frame, output reg [23:0] color);
	
	parameter PINK  = 24'hFFB8FF;
	parameter WHITE = 24'hFFFFFF;
	parameter BLUE  = 24'h0000FF;
	parameter BLACK = 24'h000000;
	
	always @ (*) begin
    case ({draw_x, 3'd7 - draw_y})
        6'b000010, 6'b000011, 6'b000100, 6'b000101: color = PINK;
        6'b001001, 6'b001010, 6'b001011, 6'b001100, 6'b001101, 6'b001110: color = PINK;
        6'b010000, 6'b010001, 6'b010010, 6'b010011, 6'b010100, 6'b010101, 6'b010110, 6'b010111: color = PINK;

        // top eye row
        6'b011000, 6'b011011, 6'b011100, 6'b011111: color = PINK;
        6'b011001: color = (direction == 2'b00 || direction == 2'b10) ? BLUE : WHITE;
        6'b011010: color = (direction == 2'b11) ? BLUE : WHITE;                        
        6'b011101: color = (direction == 2'b00 || direction == 2'b10) ? BLUE : WHITE; 
        6'b011110: color = (direction == 2'b11) ? BLUE : WHITE;                        

        // bottom eye row
        6'b100000, 6'b100011, 6'b100100, 6'b100111: color = PINK;
        6'b100001: color = (direction == 2'b01) ? BLUE : WHITE;                        
        6'b100010: color = WHITE;
        6'b100101: color = (direction == 2'b01) ? BLUE : WHITE;                       
        6'b100110: color = WHITE;

        6'b101000, 6'b101001, 6'b101010, 6'b101011, 6'b101100, 6'b101101, 6'b101110, 6'b101111: color = PINK;
        6'b110000, 6'b110001, 6'b110010, 6'b110011, 6'b110100, 6'b110101, 6'b110110, 6'b110111: color = PINK;

        // feet
        6'b111000: color = (anim_frame == 2'b00 || anim_frame == 2'b10) ? PINK : BLACK;
        6'b111001: color = PINK;
        6'b111010: color = (anim_frame == 2'b01 || anim_frame == 2'b10) ? PINK : BLACK;
        6'b111011: color = (anim_frame == 2'b00) ? PINK : BLACK;
        6'b111100: color = (anim_frame == 2'b00) ? PINK : BLACK;
        6'b111101: color = (anim_frame == 2'b01 || anim_frame == 2'b10) ? PINK : BLACK;
        6'b111110: color = PINK;
        6'b111111: color = (anim_frame == 2'b00 || anim_frame == 2'b10) ? PINK : BLACK;
        default: color = BLACK;
    endcase
end
endmodule