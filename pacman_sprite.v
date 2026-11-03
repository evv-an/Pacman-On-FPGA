module pacman_sprite(input[2:0] draw_x, input[2:0] draw_y, input[1:0] direction, output reg [23:0] color);

	reg[2:0] rotation_x;
	reg[2:0] rotation_y;

	always @ (*) begin //rotation of drawing logic
			case(direction)
				2'b11: begin 										//right
					rotation_y = draw_y;
					rotation_x = draw_x; end							//mouth opens towards +x
					
				2'b10: begin 										//left
					rotation_y = draw_y;
					rotation_x = 3'd7 - draw_x; end					//mouth opens towards -x	
					
				2'b00: begin 										//up
					rotation_y = draw_x; 
					rotation_x = 3'd7 - draw_y; end					//mouth opens towards -y
					
				2'b01: begin 										//down
					rotation_y = 3'd7 - draw_x; 
					rotation_x = draw_y; end							//mouth opens towards +y
					
				default: begin										//default (left)
					rotation_y = draw_y;
					rotation_x = 3'd7 - draw_x; end
					
			endcase
	end
	

	always @ (*) begin //drawing logic (draws range of pixels on layer _ yellow. if not in range, draw black)
		case(rotation_y)
			3'd0: color = (rotation_x >= 3'd2 && rotation_x <= 3'd6) ? 24'hFFFF00 : 24'h000000;
			3'd1: color = (rotation_x >= 3'd1 && rotation_x <= 3'd7) ? 24'hFFFF00 : 24'h000000;
			3'd2: color = (rotation_x >= 3'd1 && rotation_x <= 3'd6) ? 24'hFFFF00 : 24'h000000;
			3'd3: color = (rotation_x <= 3'd4) ? 24'hFFFF00 : 24'h000000;
			3'd4: color = (rotation_x <= 3'd2) ? 24'hFFFF00 : 24'h000000;
			3'd5: color = (rotation_x >= 3'd1 && rotation_x <= 3'd4) ? 24'hFFFF00 : 24'h000000;
			3'd6: color = (rotation_x >= 3'd1 && rotation_x <= 3'd7) ? 24'hFFFF00 : 24'h000000;
			3'd7: color = (rotation_x >= 3'd2 && rotation_x <= 3'd6) ? 24'hFFFF00 : 24'h000000;
			default: color = 24'h000000;
		endcase
	end
endmodule