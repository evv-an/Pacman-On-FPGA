module ghost_controller(
    input clk,
    input rst,
    input started,
    input release_signal,          // 1'b1 when the ghost should be released (like pellets_eaten >= 5)
    input [9:0] spawn_x,           // cage spawn x position
    input [9:0] spawn_y,
	 input frame_tick,
    input [9:0] release_x,         // x position it teleports to (outside the gate)
    input [9:0] release_y,         // y position it teleports to (outside the gate)
    input [1:0] initial_direction, // 00 up, 01 down, 10 left, 11 right
    input [4:0] target_tile_x,     // target tile x (0 to 19)
    input [3:0] target_tile_y,     // target tile y (0 to 14)
    input [1:0] speed_mask,        // speed mask (2'b11 = 75% speed)
    output reg [9:0] ghost_x_pos,
    output reg [9:0] ghost_y_pos,
    output reg [1:0] ghost_direction
);

    parameter GHOST_SIZE           = 10'd8;
    parameter VIRTUAL_PIXEL_HEIGHT = 16'd120;

    reg [1:0] speed_counter;
    reg released;

 // tile lookups for ghosts
    wire [4:0] next_tile_x_left = (ghost_x_pos > 0) ? ((ghost_x_pos - 1'b1) >> 3) : 5'd0;
    wire [4:0] next_tile_x_right = (ghost_x_pos + GHOST_SIZE) >> 3;
    wire [3:0] next_tile_y_top = (ghost_y_pos > 0) ? ((ghost_y_pos - 1'b1) >> 3) : 4'd0;
    wire [3:0] next_tile_y_down = (ghost_y_pos + GHOST_SIZE) >> 3;

    wire [4:0] curr_tile_x_left = ghost_x_pos >> 3;
    wire [4:0] curr_tile_x_right = (ghost_x_pos + GHOST_SIZE - 1'b1) >> 3;
    wire [3:0] curr_tile_y_top = ghost_y_pos >> 3;
    wire [3:0] curr_tile_y_down = (ghost_y_pos + GHOST_SIZE - 1'b1) >> 3;

    wire wall_up_left, wall_up_right;
    wire wall_down_left, wall_down_right;
    wire wall_left_top, wall_left_down;
    wire wall_right_top, wall_right_down;

    tilemap_rom tile_up_left(.tile_x(curr_tile_x_left), .tile_y(next_tile_y_top), .is_wall(wall_up_left));
    tilemap_rom tile_up_right(.tile_x(curr_tile_x_right), .tile_y(next_tile_y_top), .is_wall(wall_up_right));
    tilemap_rom tile_down_left(.tile_x(curr_tile_x_left), .tile_y(next_tile_y_down), .is_wall(wall_down_left));
    tilemap_rom tile_down_right(.tile_x(curr_tile_x_right), .tile_y(next_tile_y_down), .is_wall(wall_down_right));
    tilemap_rom tile_left_top(.tile_x(next_tile_x_left), .tile_y(curr_tile_y_top), .is_wall(wall_left_top));
    tilemap_rom tile_left_down(.tile_x(next_tile_x_left), .tile_y(curr_tile_y_down), .is_wall(wall_left_down));
    tilemap_rom tile_right_top(.tile_x(next_tile_x_right), .tile_y(curr_tile_y_top), .is_wall(wall_right_top));
    tilemap_rom tile_right_down(.tile_x(next_tile_x_right), .tile_y(curr_tile_y_down), .is_wall(wall_right_down));

    wire wall_above = wall_up_left | wall_up_right;
    wire wall_below = wall_down_left | wall_down_right;
    wire wall_left = wall_left_top | wall_left_down;
    wire wall_right = wall_right_top | wall_right_down;

 // tile center calculations for ghosts
    wire [4:0] ghost_tile_x = ghost_x_pos >> 3;
    wire [3:0] ghost_tile_y = ghost_y_pos >> 3;
    wire is_tile_center = (ghost_x_pos[2:0] == 3'd0) && (ghost_y_pos[2:0] == 3'd0);

 // targeting math (each ghost uses same target pathfinding but slightly altered [differences written in top module])
    wire [4:0] x_up = (ghost_tile_x > target_tile_x) ? (ghost_tile_x - target_tile_x) : (target_tile_x - ghost_tile_x);
    wire [4:0] x_down = x_up;
    wire [4:0] x_left = ((ghost_tile_x - 1'b1) > target_tile_x) ? ((ghost_tile_x - 1'b1) - target_tile_x) : (target_tile_x - (ghost_tile_x - 1'b1));
    wire [4:0] x_right = ((ghost_tile_x + 1'b1) > target_tile_x) ? ((ghost_tile_x + 1'b1) - target_tile_x) : (target_tile_x - (ghost_tile_x + 1'b1));

    wire [3:0] y_up = ((ghost_tile_y - 1'b1) > target_tile_y) ? ((ghost_tile_y - 1'b1) - target_tile_y) : (target_tile_y - (ghost_tile_y - 1'b1));
    wire [3:0] y_down = ((ghost_tile_y + 1'b1) > target_tile_y) ? ((ghost_tile_y + 1'b1) - target_tile_y) : (target_tile_y - (ghost_tile_y + 1'b1));
    wire [3:0] y_left = (ghost_tile_y > target_tile_y) ? (ghost_tile_y - target_tile_y) : (target_tile_y - ghost_tile_y);
    wire [3:0] y_right = y_left;

    wire [9:0] dist_up   = (wall_above || ghost_direction == 2'b01 || ghost_tile_y == 4'd0)  ? 10'h3FF : (x_up * x_up + y_up * y_up);
    wire [9:0] dist_down = (wall_below || ghost_direction == 2'b00 || ghost_tile_y == 4'd14) ? 10'h3FF : (x_down * x_down + y_down * y_down);
    wire [9:0] dist_left = (wall_left  || ghost_direction == 2'b11 || ghost_tile_x == 5'd0)  ? 10'h3FF : (x_left * x_left + y_left * y_left);
    wire [9:0] dist_right= (wall_right || ghost_direction == 2'b10 || ghost_tile_x == 5'd19) ? 10'h3FF : (x_right * x_right + y_right * y_right);

    // direction hierarchy
    wire [1:0] best_direction = (dist_up <= dist_left && dist_up <= dist_down && dist_up <= dist_right) ? 2'b00 :
                                (dist_left <= dist_down && dist_left <= dist_right) ? 2'b10 :
                                (dist_down <= dist_right) ? 2'b01 : 2'b11;

    wire [1:0] next_direction = is_tile_center ? best_direction : ghost_direction;

 // movement and release logic
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            ghost_x_pos <= spawn_x;
            ghost_y_pos <= spawn_y;
            ghost_direction <= initial_direction;
            released <= 1'b0;
            speed_counter <= 2'b00;
        end else if (started && frame_tick) begin
            // release trigger (teleport to blinky spawnpoint once condition is met)
            if (!released && release_signal) begin
                ghost_x_pos <= release_x;
                ghost_y_pos <= release_y;
                released <= 1'b1;
            end else begin
                speed_counter <= speed_counter + 1'b1;

                // slowed down to 75% speed 
                if (speed_counter != speed_mask) begin
                    ghost_direction <= next_direction;

                    case (next_direction)
                        2'b00: if (!wall_above) ghost_y_pos <= ghost_y_pos - 1'b1;
                        2'b01: if (!wall_below) ghost_y_pos <= ghost_y_pos + 1'b1;
                        2'b10: if (!wall_left)  ghost_x_pos <= ghost_x_pos - 1'b1;
                        2'b11: if (!wall_right) ghost_x_pos <= ghost_x_pos + 1'b1;
                    endcase

                    // warp hallway logic
                    if (ghost_y_pos == 1'b0)
                        ghost_y_pos <= (VIRTUAL_PIXEL_HEIGHT - GHOST_SIZE - 2'b10);
                    else if (ghost_y_pos == (VIRTUAL_PIXEL_HEIGHT - GHOST_SIZE - 1'b1))
                        ghost_y_pos <= 1'b1;
                end
            end
        end
    end

endmodule