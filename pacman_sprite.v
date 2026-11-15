module pacman_sprite(
    input [9:0] x,             
    input [9:0] y,             
    input active_pixels, 
    input [9:0] pacman_x_pos,  //virtual grid x
    input [9:0] pacman_y_pos,  //virtual grid y
    input [1:0] direction,     //up > down > left > right
    input [1:0] anim_frame,    //closed > half open > wide open > half open
    output reg [23:0] color
);

    //convert virtual coordinates to physical coordinates
    wire [9:0] pacman_left = {pacman_x_pos[7:0], 2'b00};
    wire [9:0] pacman_top = {pacman_y_pos[7:0], 2'b00};

    //checks if drawing inside pacman
    wire inside_pacman = active_pixels && (x >= pacman_left) && (x < pacman_left + 10'd32) && (y >= pacman_top)  && (y < pacman_top  + 10'd32);

    wire [4:0] offset_x = x - pacman_left;
    wire [4:0] offset_y = y - pacman_top;
    wire [3:0] sprite_x = offset_x[4:1];
    wire [3:0] sprite_y = offset_y[4:1];

    //mirror/rotate coordinates so only one drawing is needed
    reg [3:0] rotated_x;
    reg [3:0] rotated_y;

    always @(*) begin
        case (direction)
            2'b11: begin //right
                rotated_x = sprite_x;
                rotated_y = sprite_y;
            end
            2'b10: begin //left
                rotated_x = 4'd15 - sprite_x;
                rotated_y = sprite_y;
            end
            2'b00: begin //up
                rotated_x = 4'd15 - sprite_y;
                rotated_y = sprite_x;
            end
            2'b01: begin //down
                rotated_x = sprite_y;
                rotated_y = sprite_x;
            end
        endcase
    end

    reg [15:0] row_bits;

    always @(*) begin
        case (anim_frame)
            //frame 0
            2'b00: begin
                case (rotated_y)
                    4'd0: row_bits = 16'b0000011111100000;
                    4'd1: row_bits = 16'b0001111111111000; 
                    4'd2: row_bits = 16'b0011111111111100; 
                    4'd3: row_bits = 16'b0111111111111110; 
                    4'd4: row_bits = 16'b0111111111111110; 
                    4'd5: row_bits = 16'b1111111111111111; 
                    4'd6: row_bits = 16'b1111111111111111; 
                    4'd7: row_bits = 16'b1111111111111111; 
                    4'd8: row_bits = 16'b1111111111111111; 
                    4'd9: row_bits = 16'b1111111111111111; 
                    4'd10: row_bits = 16'b1111111111111111; 
                    4'd11: row_bits = 16'b0111111111111110; 
                    4'd12: row_bits = 16'b0111111111111110; 
                    4'd13: row_bits = 16'b0011111111111100; 
                    4'd14: row_bits = 16'b0001111111111000; 
                    4'd15: row_bits = 16'b0000011111100000; 
                endcase
            end

            //frames 1 and 3
            2'b01, 2'b11: begin
                case (rotated_y)
                    4'd0: row_bits = 16'b0000011111100000; 
                    4'd1: row_bits = 16'b0001111111111000; 
                    4'd2: row_bits = 16'b0011111111111100; 
                    4'd3: row_bits = 16'b0111111111111110; 
                    4'd4: row_bits = 16'b0111111111111100; 
                    4'd5: row_bits = 16'b1111111111100000; 
                    4'd6: row_bits = 16'b1111111110000000; 
                    4'd7: row_bits = 16'b1111111000000000; 
                    4'd8: row_bits = 16'b1111111000000000;
                    4'd9: row_bits = 16'b1111111110000000; 
                    4'd10: row_bits = 16'b1111111111100000; 
                    4'd11: row_bits = 16'b0111111111111100; 
                    4'd12: row_bits = 16'b0111111111111110; 
                    4'd13: row_bits = 16'b0011111111111100; 
                    4'd14: row_bits = 16'b0001111111111000; 
                    4'd15: row_bits = 16'b0000011111100000; 
                endcase
            end

            //frame 2
            2'b10: begin
                case (rotated_y)
                    4'd0: row_bits = 16'b0000011111100000; 
                    4'd1: row_bits = 16'b0001111111111000; 
                    4'd2: row_bits = 16'b0011111111111000; 
                    4'd3: row_bits = 16'b0111111111110000; 
                    4'd4: row_bits = 16'b0111111111000000; 
                    4'd5: row_bits = 16'b1111111100000000; 
                    4'd6: row_bits = 16'b1111111000000000; 
                    4'd7: row_bits = 16'b1111110000000000; 
                    4'd8: row_bits = 16'b1111110000000000; 
                    4'd9: row_bits = 16'b1111111000000000; 
                    4'd10: row_bits = 16'b1111111100000000; 
                    4'd11: row_bits = 16'b0111111111000000; 
                    4'd12: row_bits = 16'b0111111111110000; 
                    4'd13: row_bits = 16'b0011111111111000; 
                    4'd14: row_bits = 16'b0001111111111000; 
                    4'd15: row_bits = 16'b0000011111100000; 
                endcase
            end

            default: row_bits = 16'b0000000000000000;
        endcase

        color = (inside_pacman && row_bits[4'd15 - rotated_x]) ? 24'hFFFF00 : 24'h000000;
    end

endmodule