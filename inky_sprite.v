module inky_sprite(input  [2:0] draw_x, input  [2:0] draw_y, input  [1:0] direction, output reg [23:0] color);
	
	parameter CYAN   = 24'h00FFFF;
	parameter WHITE = 24'hFFFFFF;
	parameter BLUE  = 24'h0000FF;
	parameter BLACK = 24'h000000;
	
	always @ (*) begin
    case ({draw_x, 3'd7 - draw_y})
        6'b000_010, 6'b000_011, 6'b000_100, 6'b000_101: color = CYAN;
        6'b001_001, 6'b001_010, 6'b001_011, 6'b001_100, 6'b001_101, 6'b001_110: color = CYAN;
        6'b010_000, 6'b010_001, 6'b010_010, 6'b010_011, 6'b010_100, 6'b010_101, 6'b010_110, 6'b010_111: color = CYAN;

        // top eye row
        6'b011_000, 6'b011_011, 6'b011_100, 6'b011_111: color = CYAN;
        6'b011_001: color = (direction == 2'b00 || direction == 2'b10) ? BLUE : WHITE; // up or left
        6'b011_010: color = (direction == 2'b11) ? BLUE : WHITE;                        // right
        6'b011_101: color = (direction == 2'b00 || direction == 2'b10) ? BLUE : WHITE; // up or left
        6'b011_110: color = (direction == 2'b11) ? BLUE : WHITE;                        // right

        // bottom eye row
        6'b100_000, 6'b100_011, 6'b100_100, 6'b100_111: color = CYAN;
        6'b100_001: color = (direction == 2'b01) ? BLUE : WHITE;                        // down
        6'b100_010: color = WHITE;
        6'b100_101: color = (direction == 2'b01) ? BLUE : WHITE;                        // down
        6'b100_110: color = WHITE;

        6'b101_000, 6'b101_001, 6'b101_010, 6'b101_011, 6'b101_100, 6'b101_101, 6'b101_110, 6'b101_111: color = CYAN;
        6'b110_000, 6'b110_001, 6'b110_010, 6'b110_011, 6'b110_100, 6'b110_101, 6'b110_110, 6'b110_111: color = CYAN;

        // feet
        6'b111_000, 6'b111_001, 6'b111_011, 6'b111_100, 6'b111_110, 6'b111_111: color = CYAN;	
        default: color = BLACK;
    endcase
end
endmodule