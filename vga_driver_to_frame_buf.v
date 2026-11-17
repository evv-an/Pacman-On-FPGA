module vga_driver_to_frame_buf(
	output [6:0]HEX0,
	output [6:0]HEX1,
	output [6:0]HEX2,
	output [6:0]HEX3,
	output [6:0]HEX4,
	output VGA_BLANK_N,
	output [7:0]VGA_B,
	output VGA_CLK,
	output [7:0]VGA_G,
	output VGA_HS,                                        
	output [7:0]VGA_R,
	output [9:0]LEDR,
	input [3:0]KEY,	         
	input CLOCK_50,
	input [35:0]GPIO_0,	
	input [9:0]SW,													
	output VGA_SYNC_N,														
	output VGA_VS);

// circuit signals
wire clk;
wire rst;
assign clk = CLOCK_50;
assign rst = SW[9];
assign LEDR = 10'd0;

// switch debouncer
wire [9:0]SW_db;
debounce_switches my_db_switches(
	.clk(clk),
	.rst(rst),
	.SW(SW),
	.SW_db(SW_db));
	

// vga driver
wire active_pixels; // is on when we're in the active draw space
wire frame_done;
wire [9:0]x; // current x
wire [9:0]y; // current y 


// signals to draw the picture
reg [14:0] the_vga_draw_frame_write_mem_address;
reg [23:0] the_vga_draw_frame_write_mem_data;
reg the_vga_draw_frame_write_a_pixel;


// signals frame driver to activate draw_frame
wire [7:0] fb_r;
wire [7:0] fb_g;
wire [7:0] fb_b;
vga_frame_driver my_frame_driver(
	.clk(clk),
	.rst(rst),
	.active_pixels(active_pixels),
	.frame_done(frame_done),
	.x(x),
	.y(y),
	.VGA_BLANK_N(VGA_BLANK_N),
	.VGA_CLK(VGA_CLK),
	.VGA_HS(VGA_HS),
	.VGA_SYNC_N(VGA_SYNC_N),
	.VGA_VS(VGA_VS),
	.VGA_B(fb_b),
	.VGA_G(fb_g),
	.VGA_R(fb_r),
	.the_vga_draw_frame_write_mem_address(the_vga_draw_frame_write_mem_address),
	.the_vga_draw_frame_write_mem_data(the_vga_draw_frame_write_mem_data),
	.the_vga_draw_frame_write_a_pixel(the_vga_draw_frame_write_a_pixel));

parameter MEMORY_SIZE = 16'd19200; // 160*120 memory spots
parameter PIXEL_VIRTUAL_SIZE = 16'd4; // pixels per memory spot


// actual vga resolution
parameter VGA_WIDTH = 16'd640; 
parameter VGA_HEIGHT = 16'd480;


// reduce resolution to 160*120
parameter VIRTUAL_PIXEL_WIDTH = VGA_WIDTH/PIXEL_VIRTUAL_SIZE; // 160
parameter VIRTUAL_PIXEL_HEIGHT = VGA_HEIGHT/PIXEL_VIRTUAL_SIZE; // 120


//define tile for ghost cage gate and border drawing
parameter GATE_TILE_X = 5'd8; 
parameter GATE_TILE_Y = 4'd7; 
parameter TILE_ABOVE_GATE_X = 5'd8;
parameter TILE_ABOVE_GATE_Y = 4'd6;
parameter TILE_BELOW_GATE_X = 5'd8;
parameter TILE_BELOW_GATE_Y = 5'd8;

wire is_gate_tile = (tile_x_idx == GATE_TILE_X) && (tile_y_idx == GATE_TILE_Y);
wire is_gate_bar  = is_gate_tile && (draw_x == 10'd3 || draw_x == 10'd4); 
wire above_gate = (tile_x_idx == TILE_ABOVE_GATE_X) && (tile_y_idx == TILE_ABOVE_GATE_Y);
wire below_gate = (tile_x_idx == TILE_BELOW_GATE_X) && (tile_y_idx == TILE_BELOW_GATE_Y);


reg [14:0] idx_location; // stores locations


// checks current and next tile data (wall or path)
wire [4:0] next_tile_x_left = (pacman_x_pos > 0) ? ((pacman_x_pos - 1'b1) >> 3) : 5'd0;
wire [4:0] next_tile_x_right = (pacman_x_pos + PACMAN_SIZE) >> 3;
wire [3:0] next_tile_y_top = (pacman_y_pos > 0) ? ((pacman_y_pos - 1'b1) >> 3) : 4'd0;
wire [3:0] next_tile_y_bottom = (pacman_y_pos + PACMAN_SIZE) >> 3;

wire [4:0] curr_tile_x_left = pacman_x_pos >> 3;
wire [4:0] curr_tile_x_right = (pacman_x_pos + PACMAN_SIZE - 1'b1) >> 3;
wire [3:0] curr_tile_y_top = pacman_y_pos >> 3;
wire [3:0] curr_tile_y_bottom = (pacman_y_pos + PACMAN_SIZE - 1'b1) >> 3;


// splits each 8x8 tile into 4x4 corners (0-3 from the closest edge) so one pattern covers all four
wire [1:0] corner_offset_x = draw_x[2] ? ~draw_x[1:0] : draw_x[1:0];
wire [1:0] corner_offset_y = draw_y[2] ? ~draw_y[1:0] : draw_y[1:0];
wire [3:0] quadrant_index  = {corner_offset_y, corner_offset_x};
						
wire horizontal_edge_open = draw_x[2] ? !wall_right_render : !wall_left_render;
wire vertical_edge_open   = draw_y[2] ? (!wall_below_render || above_gate) : (!wall_above_render || below_gate);
wire diagonal_path_open   = draw_y[2] ? (draw_x[2] ? !wall_below_right_render : !wall_below_left_render)
                                      : (draw_x[2] ? !wall_above_right_render : !wall_above_left_render);

wire is_outer_wall = (tile_x_idx == 5'd0) || (tile_x_idx == 5'd19) ||
                     (tile_y_idx == 4'd0) || (tile_y_idx == 4'd14) ||
                     ((tile_x_idx <= 5'd2)  && wall_left_render)  ||
                     ((tile_x_idx >= 5'd17) && wall_right_render) ||
                     ((tile_y_idx <= 4'd2)  && wall_above_render) ||
                     ((tile_y_idx >= 4'd12) && wall_below_render);

reg [15:0] corner_pattern;
reg [15:0] fill_pattern;
always @(*) begin
    if (horizontal_edge_open && vertical_edge_open) begin
        corner_pattern = is_outer_wall ? 16'b1101_1001_0010_1100 : 16'b0001_0001_0010_1100;
        fill_pattern = is_outer_wall ? 16'b0010_0110_1100_0000 : 16'b1110_1110_1100_0000;
    end else if (horizontal_edge_open) begin
        corner_pattern = is_outer_wall ? 16'b0101_0101_0101_0101 : 16'b0001_0001_0001_0001;
        fill_pattern = is_outer_wall ? 16'b0010_0010_0010_0010 : 16'b1110_1110_1110_1110;
    end else if (vertical_edge_open) begin
        corner_pattern = is_outer_wall ? 16'b0000_1111_0000_1111 : 16'b0000_0000_0000_1111;
        fill_pattern = is_outer_wall ? 16'b0000_0000_1111_0000 : 16'b1111_1111_1111_0000;
    end else if (diagonal_path_open) begin
        corner_pattern = is_outer_wall ? 16'b0000_0001_0010_0101 : 16'b0000_0000_0000_0001;
        fill_pattern = is_outer_wall ? 16'b0000_0000_0001_0010 : 16'b1111_1111_1111_1110;
    end else begin
        corner_pattern = 16'b0000_0000_0000_0000;
        fill_pattern = is_outer_wall ? 16'b0000_0000_0000_0000 : 16'b1111_1111_1111_1111;
    end
end

wire outside_rounded_corner = horizontal_edge_open && vertical_edge_open && (quadrant_index == 4'd0 || quadrant_index == 4'd1 || quadrant_index == 4'd4);
wire is_wall_border = !is_gate_tile && is_draw_wall && corner_pattern[quadrant_index];
wire is_wall_fill = level && !is_gate_tile && is_draw_wall && fill_pattern[quadrant_index];

wire [23:0] wall_border_color = flash_walls_white ? 24'hFFFFFF : easter_egg1_active ? 24'h00FF00 : easter_egg2_active ? 24'hB848FF : level ? 24'hD80038 : 24'h0000FF;
wire [23:0] wall_fill_color = easter_egg2_active ? 24'h340C54 : 24'hFFB897;

// levels

reg level;
reg level_transition;
reg [6:0] level_clear_timer; 

wire flash_walls_white = (level_clear_timer > 7'd0) && level_clear_timer[4];


parameter TOTAL_PELLETS_L1 = 13'd116;
parameter TOTAL_PELLETS_L2 = 13'd116;
wire[12:0] current_total_pellets = level ? TOTAL_PELLETS_L2 : TOTAL_PELLETS_L1;
reg[12:0] saved_pellets_eaten;
reg[12:0] saved_super_pellets_eaten;
reg[15:0] saved_ghost_score;


// variables for respawn & lives function
reg [2:0] lives;
reg game_over_active;
reg game_won_active; 
reg [6:0] death_timer;

//pacman drawing & animations					
reg [1:0] direction;
wire [23:0] raw_pacman_color;
reg [4:0] pacman_anim_timer;
wire [1:0] anim_frame = pacman_anim_timer[4:3];
pacman_sprite pacman_render(
    .x(x),
    .y(y),
    .active_pixels(active_pixels),
    .pacman_x_pos(pacman_x_pos),
    .pacman_y_pos(pacman_y_pos),
    .direction(direction),
	 .level(level),
    .anim_frame(anim_frame),
    .color(raw_pacman_color)
);


// text drawing
wire [23:0] game_over_color;
game_over_text game_over_render_inst(
    .tile_x_idx(tile_x_idx),
    .tile_y_idx(tile_y_idx),
    .draw_x(draw_x[2:0]),
    .draw_y(draw_y[2:0]),
    .game_over_active(game_over_active),
    .color(game_over_color));
	 
wire [23:0] game_won_color;
game_won_text game_won_render_inst(
    .tile_x_idx(tile_x_idx),
    .tile_y_idx(tile_y_idx),
    .draw_x(draw_x[2:0]),
    .draw_y(draw_y[2:0]),
    .game_won_active(game_won_active),
    .color(game_won_color));

	 
//pellet system logic & registers 
reg [299:0] eaten_pellet;
reg [12:0] pellets_eaten; //counter
reg [12:0] super_pellets_eaten; //counter
reg [299:0] eaten_super_pellet;
reg [4:0] super_pellet_blink_counter;	
wire [23:0] pellet_color = easter_egg1_active ? 24'hEBB434 : (level ? 24'hFFFFFF : 24'hFFB8AE);

wire[4:0] pacman_center_tile_x = (pacman_x_pos + 10'd4) >> 3; //knows when pacman hits center of tile
wire[3:0] pacman_center_tile_y = (pacman_y_pos + 10'd4) >> 3; 

wire[8:0] eat_idx = (pacman_center_tile_y * 5'd20) + (5'd19 - pacman_center_tile_x); //tracks pacman tile index for eating while moving
wire[8:0] draw_idx = (tile_y_idx * 5'd20) + (5'd19 - tile_x_idx);							 //tracks tile index being scanned by vga renderer

//game logic: locations pellets cannot spawn (ranges of tiles)
wire warp_hallway = (pacman_center_tile_x == 5'd9) && (pacman_center_tile_y <= 4'd1 || pacman_center_tile_y >= 4'd13 || pacman_center_tile_y == 4'd3 || pacman_center_tile_y == 4'd11);
wire ghost_cage = (pacman_center_tile_x >= 5'd6 && pacman_center_tile_x <= 5'd12) && (pacman_center_tile_y >= 4'd4 && pacman_center_tile_y <= 4'd10);
wire spawn_tile = ((pacman_center_tile_x == 5'd16) && (pacman_center_tile_y == 4'd7)) || ((pacman_center_tile_x == 5'd5) && (pacman_center_tile_y == 4'd1)) || ((pacman_center_tile_x == 5'd13) && (pacman_center_tile_y == 4'd13));
wire l1_no_pellet = warp_hallway || ghost_cage || spawn_tile;

//level 2 
wire l2_spawn = (pacman_center_tile_x == 5'd9 && (pacman_center_tile_y == 4'd1 || pacman_center_tile_y == 4'd13)) || (pacman_center_tile_x == 5'd6 && (pacman_center_tile_y == 4'd4 || pacman_center_tile_y == 4'd10));
wire l2_no_spawn = ((pacman_center_tile_y == 4'd3 || pacman_center_tile_y == 4'd11) && (pacman_center_tile_x == 5'd8 || (pacman_center_tile_x >= 5'd10 && pacman_center_tile_x <= 5'd12))) || (pacman_center_tile_x == 5'd10 && (pacman_center_tile_y == 4'd2 || pacman_center_tile_y == 4'd12));
wire no_pellet = level ? ((l1_no_pellet && !l2_spawn) || l2_no_spawn) : l1_no_pellet;

//vga logic: locations pellets cannot spawn (ranges of tiles)
wire draw_is_warp_hallway = (tile_x_idx == 5'd9) && (tile_y_idx <= 4'd1 || tile_y_idx >= 4'd13 || tile_y_idx == 4'd3 || tile_y_idx == 4'd11);
wire draw_is_ghost_cage = (tile_x_idx >= 5'd6 && tile_x_idx <= 5'd12) && (tile_y_idx >= 4'd4 && tile_y_idx <= 4'd10);
wire draw_is_spawn_tile = ((tile_x_idx == 5'd16) && (tile_y_idx == 4'd7)) || ((tile_x_idx == 5'd5) && (tile_y_idx == 4'd1)) || ((tile_x_idx == 5'd13) && (tile_y_idx == 4'd13));
wire l1_draw_no_pellet = draw_is_warp_hallway || draw_is_ghost_cage || draw_is_spawn_tile;

//level 2
wire draw_l2_spawn = (tile_x_idx == 5'd9 && (tile_y_idx == 4'd1 || tile_y_idx == 4'd13)) || (tile_x_idx == 5'd6 && (tile_y_idx == 4'd4 || tile_y_idx == 4'd10));
wire draw_l2_no_spawn = ((tile_y_idx == 4'd3 || tile_y_idx == 4'd11) && (tile_x_idx == 5'd8 || (tile_x_idx >= 5'd10 && tile_x_idx <= 5'd12))) || (tile_x_idx == 5'd10 && (tile_y_idx == 4'd2 || tile_y_idx == 4'd12));
wire draw_no_pellet = level ? ((l1_draw_no_pellet && !draw_l2_spawn) || draw_l2_no_spawn) : l1_draw_no_pellet;

wire is_pellet_center = (draw_x >= 10'd3 && draw_x <= 10'd4) && (draw_y >= 10'd3 && draw_y <= 10'd4); //pellet 2x2 dot in center of tile
wire is_pellet_eaten = eaten_pellet[draw_idx]; //checks if pellet is already eaten
wire draw_pellet = !is_draw_wall && !draw_no_pellet && !is_pellet_eaten && is_pellet_center;

//super pellet 1 and 2 logic
wire is_super_pellet_corner = (draw_x == 10'd2 || draw_x == 10'd5) && (draw_y == 10'd2 || draw_y == 10'd5);
wire is_super_pellet_center = (draw_x >= 10'd2 && draw_x <= 10'd5) && (draw_y >= 10'd2 && draw_y <= 10'd5) && !is_super_pellet_corner;
wire is_super_pellet_eaten = eaten_super_pellet[draw_idx];
wire draw_super_pellet = (((tile_x_idx == 5'd5) && (tile_y_idx == 4'd1)) || ((tile_x_idx == 5'd13) && (tile_y_idx == 4'd13))) && is_super_pellet_center && !is_super_pellet_eaten && super_pellet_visible;
wire is_super_pellet = ((pacman_center_tile_x == 5'd5) && (pacman_center_tile_y == 4'd1)) || ((pacman_center_tile_x == 5'd13) && (pacman_center_tile_y == 4'd13));
wire super_pellet_visible = (super_pellet_blink_counter < 5'd15);

//each super pellet ghost score math & instantiations
wire is_pellet1 = (pacman_center_tile_x == 5'd5)  && (pacman_center_tile_y == 4'd1);
wire is_pellet2 = (pacman_center_tile_x == 5'd13) && (pacman_center_tile_y == 4'd13);

reg active_pellet;           
reg [12:0] pellet1_ghost_count; // capped at 4 ghosts max per pellet
reg [12:0] pellet2_ghost_count;
reg en_pellet1;              
reg en_pellet2;

wire [12:0] pellet1_score_out;
wire [12:0] pellet2_score_out;
wire [15:0] total_ghost_score = pellet1_score_out + pellet2_score_out;

ghost_reg pellet1_score_reg (
    .clk(clk),
    .rst(rst && !level_transition),
    .en(en_pellet1),
    .ghost_count(pellet1_ghost_count),
    .ghost_score(pellet1_score_out)
);

ghost_reg pellet2_score_reg (
    .clk(clk),
    .rst(rst && !level_transition),
    .en(en_pellet2),
    .ghost_count(pellet2_ghost_count),
    .ghost_score(pellet2_score_out)
);


// searches for a wall around pacman
wire wall_above;
wire wall_below;
wire wall_left;
wire wall_right;

assign wall_left = w_lt_t | w_lt_b;
assign wall_above = w_up_l | w_up_r;
assign wall_below = w_dn_l | w_dn_r;
assign wall_right = w_rt_t | w_rt_b;

wire w_lt_t; // left top / bottom
wire w_lt_b;
wire w_up_l; // up left / right
wire w_up_r;
wire w_dn_l; // down left / right
wire w_dn_r;
wire w_rt_t; // right top / bottom
wire w_rt_b;

// instantiate for current and next tile data
tilemap_rom tile_up_l(.level(level), .tile_x(curr_tile_x_left), .tile_y(next_tile_y_top), .is_wall(w_up_l));
tilemap_rom tile_up_r(.level(level), .tile_x(curr_tile_x_right), .tile_y(next_tile_y_top), .is_wall(w_up_r));
tilemap_rom tile_dn_l(.level(level), .tile_x(curr_tile_x_left), .tile_y(next_tile_y_bottom), .is_wall(w_dn_l));
tilemap_rom tile_dn_r(.level(level), .tile_x(curr_tile_x_right), .tile_y(next_tile_y_bottom), .is_wall(w_dn_r));
tilemap_rom tile_lt_t(.level(level), .tile_x(next_tile_x_left), .tile_y(curr_tile_y_top), .is_wall(w_lt_t));
tilemap_rom tile_lt_b(.level(level), .tile_x(next_tile_x_left), .tile_y(curr_tile_y_bottom), .is_wall(w_lt_b));
tilemap_rom tile_rt_t(.level(level), .tile_x(next_tile_x_right), .tile_y(curr_tile_y_top), .is_wall(w_rt_t));
tilemap_rom tile_rt_b(.level(level), .tile_x(next_tile_x_right), .tile_y(curr_tile_y_bottom), .is_wall(w_rt_b));

	
// tile logic (1:wall, 0:path)
reg [4:0] tile_x_idx; // 0 to 19 (8x8 pixel tiles)
reg [3:0] tile_y_idx; // 0 to 14
wire is_draw_wall;

tilemap_rom map_render(.level(level), .tile_x(tile_x_idx), .tile_y(tile_y_idx), .is_wall(is_draw_wall));	 

// detects walls around path tiles				
wire wall_above_render;
wire wall_below_render;
wire wall_left_render;
wire wall_right_render;

tilemap_rom map_up(.level(level), .tile_x(tile_x_idx), .tile_y((tile_y_idx > 0) ? (tile_y_idx - 1'b1) : 4'd0), .is_wall(wall_above_render));
tilemap_rom map_dn(.level(level), .tile_x(tile_x_idx), .tile_y((tile_y_idx < 4'd14) ? (tile_y_idx + 1'b1) : 4'd14), .is_wall(wall_below_render));
tilemap_rom map_lt(.level(level), .tile_x((tile_x_idx > 0) ? (tile_x_idx - 1'b1) : 5'd0), .tile_y(tile_y_idx), .is_wall(wall_left_render));
tilemap_rom map_rt(.level(level), .tile_x((tile_x_idx < 5'd19) ? (tile_x_idx + 1'b1) : 5'd19), .tile_y(tile_y_idx), .is_wall(wall_right_render));

wire wall_above_left_render;
wire wall_above_right_render;
wire wall_below_left_render;
wire wall_below_right_render;

tilemap_rom map_above_left(.level(level), .tile_x((tile_x_idx > 0) ? (tile_x_idx - 1'b1) : 5'd0), .tile_y((tile_y_idx > 0) ? (tile_y_idx - 1'b1) : 4'd0), .is_wall(wall_above_left_render));
tilemap_rom map_above_right(.level(level), .tile_x((tile_x_idx < 5'd19) ? (tile_x_idx + 1'b1) : 5'd19), .tile_y((tile_y_idx > 0) ? (tile_y_idx - 1'b1) : 4'd0), .is_wall(wall_above_right_render));
tilemap_rom map_below_left(.level(level), .tile_x((tile_x_idx > 0) ? (tile_x_idx - 1'b1) : 5'd0), .tile_y((tile_y_idx < 4'd14) ? (tile_y_idx + 1'b1) : 4'd14), .is_wall(wall_below_left_render));
tilemap_rom map_below_right(.level(level), .tile_x((tile_x_idx < 5'd19) ? (tile_x_idx + 1'b1) : 5'd19), .tile_y((tile_y_idx < 4'd14) ? (tile_y_idx + 1'b1) : 4'd14), .is_wall(wall_below_right_render));
	
//pacman location & size
reg[9:0] pacman_x_pos;
reg[9:0] pacman_y_pos;
parameter PACMAN_SIZE = 10'd8; //dimensions of pacman (also tile length and width)


//ghost frightened stage logic
wire ghost_rst = rst && !(death_timer == 7'd1) && !level_transition;
reg [8:0] frightened_timer; // 360 frames = 6 seconds at 60hz
wire is_frightened = (frightened_timer > 9'd0); 

//ghost feet animations
reg [3:0] ghost_anim_timer;
reg [1:0] ghost_anim_frame;
reg easter_egg1_active;
reg easter_egg2_active;


//ghost scared tracking logic (cleared individually when eaten)
reg blinky_scared, pinky_scared, inky_scared, clyde_scared;

wire blinky_is_frightened = is_frightened && blinky_scared;
wire pinky_is_frightened  = is_frightened && pinky_scared;
wire inky_is_frightened   = is_frightened && inky_scared;
wire clyde_is_frightened  = is_frightened && clyde_scared;

wire blinky_eaten = (blinky_respawn_timer > 8'd0);
wire pinky_eaten  = (pinky_respawn_timer > 8'd0);
wire inky_eaten   = (inky_respawn_timer > 8'd0);
wire clyde_eaten  = (clyde_respawn_timer > 8'd0);

reg [7:0] blinky_respawn_timer;
reg [7:0] pinky_respawn_timer;
reg [7:0] inky_respawn_timer;
reg [7:0] clyde_respawn_timer;

// ghost position wires from ai controllers
wire [9:0] blinky_x_pos, blinky_y_pos;
wire [9:0] pinky_x_pos,  pinky_y_pos;
wire [9:0] inky_x_pos,   inky_y_pos;
wire [9:0] clyde_x_pos,  clyde_y_pos;

wire [1:0] blinky_dir, pinky_dir, inky_dir, clyde_dir;


//pacman eating/dying to ghost logic
wire [9:0] blinky_hit_dx = (pacman_x_pos > blinky_x_pos) ? (pacman_x_pos - blinky_x_pos) : (blinky_x_pos - pacman_x_pos);
wire [9:0] blinky_hit_dy = (pacman_y_pos > blinky_y_pos) ? (pacman_y_pos - blinky_y_pos) : (blinky_y_pos - pacman_y_pos);
wire blinky_hit = (blinky_hit_dx < 10'd6) && (blinky_hit_dy < 10'd6);

wire [9:0] pinky_hit_dx = (pacman_x_pos > pinky_x_pos) ? (pacman_x_pos - pinky_x_pos) : (pinky_x_pos - pacman_x_pos);
wire [9:0] pinky_hit_dy = (pacman_y_pos > pinky_y_pos) ? (pacman_y_pos - pinky_y_pos) : (pinky_y_pos - pacman_y_pos);
wire pinky_hit = (pinky_hit_dx < 10'd6) && (pinky_hit_dy < 10'd6);

wire [9:0] inky_hit_dx = (pacman_x_pos > inky_x_pos) ? (pacman_x_pos - inky_x_pos) : (inky_x_pos - pacman_x_pos);
wire [9:0] inky_hit_dy = (pacman_y_pos > inky_y_pos) ? (pacman_y_pos - inky_y_pos) : (inky_y_pos - pacman_y_pos);
wire inky_hit = (inky_hit_dx < 10'd6) && (inky_hit_dy < 10'd6);

wire [9:0] clyde_hit_dx = (pacman_x_pos > clyde_x_pos) ? (pacman_x_pos - clyde_x_pos) : (clyde_x_pos - pacman_x_pos);
wire [9:0] clyde_hit_dy = (pacman_y_pos > clyde_y_pos) ? (pacman_y_pos - clyde_y_pos) : (clyde_y_pos - pacman_y_pos);
wire clyde_hit = (clyde_hit_dx < 10'd6) && (clyde_hit_dy < 10'd6);

wire eat_blinky = blinky_is_frightened && blinky_hit && !blinky_eaten;
wire eat_pinky  = pinky_is_frightened  && pinky_hit  && !pinky_eaten;
wire eat_inky   = inky_is_frightened   && inky_hit   && !inky_eaten;
wire eat_clyde  = clyde_is_frightened  && clyde_hit  && !clyde_eaten;
wire [2:0] ghosts_eaten_now = {2'd0, eat_blinky} + {2'd0, eat_pinky} + {2'd0, eat_inky} + {2'd0, eat_clyde};


wire pacman_die_collision = (
    (blinky_hit && !blinky_is_frightened && !blinky_eaten) ||
    (pinky_hit  && !pinky_is_frightened  && !pinky_eaten)  ||
    (inky_hit   && !inky_is_frightened   && !inky_eaten)   ||
    (clyde_hit  && !clyde_is_frightened  && !clyde_eaten)
);

//sends ghost back to cage after eaten
wire blinky_rst = ghost_rst && !blinky_eaten;
wire pinky_rst  = ghost_rst && !pinky_eaten;
wire inky_rst   = ghost_rst && !inky_eaten;
wire clyde_rst  = ghost_rst && !clyde_eaten;


//ghost stall after respawn (0.5 seconds)
reg [7:0] stagger_timer;
wire blinky_release_sig = 1'b1;
wire pinky_release_sig  = (pellets_eaten >= 13'd5)  && (stagger_timer >= 8'd30);
wire inky_release_sig   = (pellets_eaten >= 13'd30) && (stagger_timer >= 8'd60);
wire clyde_release_sig  = (pellets_eaten >= 13'd60) && (stagger_timer >= 8'd90);


//normal state targeting calculations

wire [4:0] blinky_tile_x = blinky_x_pos >> 3;
wire [3:0] blinky_tile_y = blinky_y_pos >> 3;

wire [5:0] pacman_2x_x = pacman_center_tile_x << 1;
wire [4:0] pacman_2x_y = pacman_center_tile_y << 1;

wire [4:0] clyde_tile_x = clyde_x_pos >> 3;
wire [3:0] clyde_tile_y = clyde_y_pos >> 3;
wire [4:0] clyde_dx = (clyde_tile_x > pacman_center_tile_x) ? (clyde_tile_x - pacman_center_tile_x) : (pacman_center_tile_x - clyde_tile_x);
wire [3:0] clyde_dy = (clyde_tile_y > pacman_center_tile_y) ? (clyde_tile_y - pacman_center_tile_y) : (pacman_center_tile_y - clyde_tile_y);
wire [9:0] clyde_dist_sq = (clyde_dx * clyde_dx) + (clyde_dy * clyde_dy);

//scared state ghost targeting (flee to corners)
wire [4:0] flee_x = (pacman_center_tile_x < 5'd10) ? 5'd19 : 5'd0;
wire [3:0] flee_y = (pacman_center_tile_y < 4'd7)  ? 4'd14 : 4'd0;

wire [4:0] blinky_target_x = blinky_is_frightened ? flee_x : pacman_center_tile_x;
wire [3:0] blinky_target_y = blinky_is_frightened ? flee_y : pacman_center_tile_y;

wire [4:0] pinky_target_x = pinky_is_frightened ? 5'd0 : ((direction == 2'b11) ? ((pacman_center_tile_x < 5'd15) ? pacman_center_tile_x + 5'd4 : 5'd19) : (direction == 2'b10) ? ((pacman_center_tile_x > 5'd4) ? pacman_center_tile_x - 5'd4 : 5'd0) : pacman_center_tile_x);
wire [3:0] pinky_target_y = pinky_is_frightened ? 4'd0 : ((direction == 2'b01) ? ((pacman_center_tile_y < 4'd10) ? pacman_center_tile_y + 4'd4 : 4'd14) : (direction == 2'b00) ? ((pacman_center_tile_y > 4'd4) ? pacman_center_tile_y - 4'd4 : 4'd0) : pacman_center_tile_y);

wire [4:0] inky_target_x = inky_is_frightened ? 5'd19 : ((pacman_2x_x < blinky_tile_x) ? 5'd0 : ((pacman_2x_x - blinky_tile_x) > 5'd19) ? 5'd19 : (pacman_2x_x - blinky_tile_x));
wire [3:0] inky_target_y = inky_is_frightened ? 4'd14 : ((pacman_2x_y < blinky_tile_y) ? 4'd0 : ((pacman_2x_y - blinky_tile_y) > 4'd14) ? 4'd14 : (pacman_2x_y - blinky_tile_y));

wire [4:0] clyde_target_x = clyde_is_frightened ? 5'd0 : ((clyde_dist_sq > 10'd64) ? pacman_center_tile_x : 5'd0);
wire [3:0] clyde_target_y = clyde_is_frightened ? 4'd14 : ((clyde_dist_sq > 10'd64) ? pacman_center_tile_y : 4'd14);


//ghost ai controller instantiations

wire [9:0] blinky_spawn_x = blinky_eaten ? 10'd72 : 10'd56;
wire [9:0] blinky_spawn_y = 10'd56;

ghost_controller blinky_ai(
    .clk(clk), .rst(blinky_rst), .started(started), 
	 .level(level),
    .release_signal(blinky_release_sig),
    .frame_tick(frame_tick),
    .spawn_x(blinky_spawn_x), .spawn_y(blinky_spawn_y),
    .release_x(10'd56), .release_y(10'd56),
    .initial_direction(2'b10),
    .target_tile_x(blinky_target_x), .target_tile_y(blinky_target_y),
    .speed_mask(2'b11),
    .ghost_x_pos(blinky_x_pos), .ghost_y_pos(blinky_y_pos), .ghost_direction(blinky_dir)
);

ghost_controller pinky_ai(
    .clk(clk), .rst(pinky_rst), .started(started), 
	 .level(level),
    .release_signal(pinky_release_sig),
    .spawn_x(10'd72), .spawn_y(10'd64),
    .release_x(10'd56), .release_y(10'd56),
    .initial_direction(2'b01),
    .frame_tick(frame_tick),
    .target_tile_x(pinky_target_x), .target_tile_y(pinky_target_y),
    .speed_mask(2'b11),
    .ghost_x_pos(pinky_x_pos), .ghost_y_pos(pinky_y_pos), .ghost_direction(pinky_dir)
);

ghost_controller inky_ai(
    .clk(clk), .rst(inky_rst), .started(started), 
	 .level(level),
    .release_signal(inky_release_sig),
    .spawn_x(10'd72), .spawn_y(10'd56),
    .release_x(10'd56), .release_y(10'd56),
    .initial_direction(2'b00),
    .frame_tick(frame_tick),
    .target_tile_x(inky_target_x), .target_tile_y(inky_target_y),
    .speed_mask(2'b11),
    .ghost_x_pos(inky_x_pos), .ghost_y_pos(inky_y_pos), .ghost_direction(inky_dir)
);

ghost_controller clyde_ai(
    .clk(clk), .rst(clyde_rst), .started(started), 
	 .level(level),
    .release_signal(clyde_release_sig),
    .spawn_x(10'd72), .spawn_y(10'd48),
    .release_x(10'd56), .release_y(10'd56),
    .initial_direction(2'b00),
    .frame_tick(frame_tick),
    .target_tile_x(clyde_target_x), .target_tile_y(clyde_target_y),
    .speed_mask(2'b11),
    .ghost_x_pos(clyde_x_pos), .ghost_y_pos(clyde_y_pos), .ghost_direction(clyde_dir)
);


//individual ghost color wires
wire [23:0] blinky_raw_color;
wire [23:0] pinky_raw_color;
wire [23:0] inky_raw_color;
wire [23:0] clyde_raw_color;


//ghost coloring instantiations (ghostname_sprite.v)
blinky_sprite blinky_render(.x(x), .y(y), .active_pixels(active_pixels), .blinky_x_pos(blinky_x_pos), .blinky_y_pos(blinky_y_pos), .direction(blinky_dir), .anim_frame(ghost_anim_frame), .color(blinky_raw_color));
pinky_sprite pinky_render(.x(x), .y(y), .active_pixels(active_pixels), .pinky_x_pos(pinky_x_pos), .pinky_y_pos(pinky_y_pos), .direction(pinky_dir), .anim_frame(ghost_anim_frame), .color(pinky_raw_color));
inky_sprite inky_render(.x(x), .y(y), .active_pixels(active_pixels), .inky_x_pos(inky_x_pos), .inky_y_pos(inky_y_pos), .direction(inky_dir), .anim_frame(ghost_anim_frame), .color(inky_raw_color));
clyde_sprite clyde_render(.x(x), .y(y), .active_pixels(active_pixels), .clyde_x_pos(clyde_x_pos), .clyde_y_pos(clyde_y_pos), .direction(clyde_dir), .anim_frame(ghost_anim_frame), .color(clyde_raw_color));

//easter egg stuff (single mario and single goomba shared by all 4 ghosts)
wire [23:0] mario_color;
mario_sprite mario_render_inst(
    .x(x),
    .y(y),
    .active_pixels(active_pixels),
    .mario_x_pos(pacman_x_pos),
    .mario_y_pos(pacman_y_pos),
    .direction(direction),
    .color(mario_color)
);

wire [9:0] blinky_left = {blinky_x_pos[7:0], 2'b00};
wire [9:0] blinky_top  = {blinky_y_pos[7:0], 2'b00};
wire inside_blinky_box = (x >= blinky_left) && (x < blinky_left + 10'd32) && (y >= blinky_top) && (y < blinky_top + 10'd32);

wire [9:0] pinky_left = {pinky_x_pos[7:0], 2'b00};
wire [9:0] pinky_top  = {pinky_y_pos[7:0], 2'b00};
wire inside_pinky_box = (x >= pinky_left) && (x < pinky_left + 10'd32) && (y >= pinky_top) && (y < pinky_top + 10'd32);

wire [9:0] inky_left = {inky_x_pos[7:0], 2'b00};
wire [9:0] inky_top  = {inky_y_pos[7:0], 2'b00};
wire inside_inky_box = (x >= inky_left) && (x < inky_left + 10'd32) && (y >= inky_top) && (y < inky_top + 10'd32);

wire [9:0] clyde_left = {clyde_x_pos[7:0], 2'b00};
wire [9:0] clyde_top  = {clyde_y_pos[7:0], 2'b00};
wire inside_clyde_box = (x >= clyde_left) && (x < clyde_left + 10'd32) && (y >= clyde_top) && (y < clyde_top + 10'd32);

wire [9:0] goomba_x_pos = inside_blinky_box ? blinky_x_pos :
                          inside_pinky_box  ? pinky_x_pos  :
                          inside_inky_box   ? inky_x_pos   :
                          inside_clyde_box  ? clyde_x_pos  :
                                              10'd640;
															 
wire [9:0] goomba_y_pos = inside_blinky_box ? blinky_y_pos :
                          inside_pinky_box  ? pinky_y_pos  :
                          inside_inky_box   ? inky_y_pos   :
                          inside_clyde_box  ? clyde_y_pos  :
                                              10'd640;

wire goomba_is_scared = inside_blinky_box ? blinky_is_frightened :
                        inside_pinky_box  ? pinky_is_frightened  :
                        inside_inky_box   ? inky_is_frightened   :
                        inside_clyde_box  ? clyde_is_frightened  :
                                            1'b0;

wire [23:0] goomba_color;
goomba_sprite goomba_render_inst(
    .x(x),
    .y(y),
    .active_pixels(active_pixels),
    .goomba_x_pos(goomba_x_pos),
    .goomba_y_pos(goomba_y_pos),
    .anim_frame(ghost_anim_frame),
    .color(goomba_color)
);

wire [23:0] scared_goomba_color;
scared_goomba_sprite scared_goomba_render_inst(
    .x(x),
    .y(y),
    .active_pixels(active_pixels),
    .goomba_x_pos(goomba_x_pos),
    .goomba_y_pos(goomba_y_pos),
    .anim_frame(ghost_anim_frame),
    .flash(frightened_timer < 9'd90 && super_pellet_blink_counter[3]),
    .color(scared_goomba_color)
);

wire [23:0] peach_color;
peach_sprite peach_render_inst(
    .x(x),
    .y(y),
    .active_pixels(active_pixels),
    .peach_x_pos(pacman_x_pos),
    .peach_y_pos(pacman_y_pos),
    .direction(direction),
    .anim_frame(anim_frame),
    .color(peach_color)
);

wire [23:0] shy_guy_color;
shy_guy_sprite shy_guy_render_inst(
    .x(x),
    .y(y),
    .active_pixels(active_pixels),
    .shy_guy_x_pos(goomba_x_pos),
    .shy_guy_y_pos(goomba_y_pos),
    .anim_frame(ghost_anim_frame),
    .color(shy_guy_color)
);

//wire [23:0] scared_shy_guy_color;
//scared_shy_guy_sprite scared_shy_guy_render_inst(
//    .x(x),
//    .y(y),
//    .active_pixels(active_pixels),
//    .shy_guy_x_pos(goomba_x_pos),
//    .shy_guy_y_pos(goomba_y_pos),
//    .anim_frame(ghost_anim_frame),
//    .flash(frightened_timer < 9'd90 && super_pellet_blink_counter[3]),
//    .color(scared_shy_guy_color)
//);

//single scared ghost shared across all 4 ghosts
wire in_scared_blinky = blinky_is_frightened && inside_blinky_box;
wire in_scared_pinky  = pinky_is_frightened  && inside_pinky_box;
wire in_scared_inky   = inky_is_frightened   && inside_inky_box;
wire in_scared_clyde  = clyde_is_frightened  && inside_clyde_box;

wire [9:0] scared_x_pos = in_scared_blinky ? blinky_x_pos :
                          in_scared_pinky  ? pinky_x_pos  :
                          in_scared_inky   ? inky_x_pos   :
                          in_scared_clyde  ? clyde_x_pos  :
                                             10'd640;

wire [9:0] scared_y_pos = in_scared_blinky ? blinky_y_pos :
                          in_scared_pinky  ? pinky_y_pos  :
                          in_scared_inky   ? inky_y_pos   :
                          in_scared_clyde  ? clyde_y_pos  :
                                             10'd640;

wire [23:0] scared_raw_color;
scared_ghost_sprite scared_render_inst(
    .x(x),
    .y(y),
    .active_pixels(active_pixels),
    .ghost_x_pos(scared_x_pos),
    .ghost_y_pos(scared_y_pos),
    .anim_frame(ghost_anim_frame),
    .flash(frightened_timer < 9'd90 && super_pellet_blink_counter[3]),
    .color(scared_raw_color)
);

//final vga output mux
wire any_easter_egg = easter_egg1_active || easter_egg2_active;
wire player_visible = (death_timer == 7'd0) || death_timer[3];
wire [23:0] active_player_color = easter_egg1_active ? mario_color : easter_egg2_active ? peach_color : raw_pacman_color;
wire [23:0] final_player_color  = player_visible ? active_player_color : 24'h000000;

wire show_heart0 = ((3'd0 < lives) || (3'd0 == lives && death_timer > 7'd0)) && player_visible;
wire show_heart1 = ((3'd1 < lives) || (3'd1 == lives && death_timer > 7'd0)) && player_visible;
wire show_heart2 = ((3'd2 < lives) || (3'd2 == lives && death_timer > 7'd0)) && player_visible;
wire show_heart3 = ((3'd3 < lives) || (3'd3 == lives && death_timer > 7'd0)) && player_visible;

wire in_heart_x = (x >= 10'd609) && (x < 10'd639);
wire in_heart0  = show_heart0 && in_heart_x && (y >= 10'd420) && (y < 10'd452);
wire in_heart1  = show_heart1 && in_heart_x && (y >= 10'd380) && (y < 10'd412);
wire in_heart2  = show_heart2 && in_heart_x && (y >= 10'd340) && (y < 10'd372);
wire in_heart3  = show_heart3 && in_heart_x && (y >= 10'd300) && (y < 10'd332);

wire [9:0] active_heart_y = in_heart0 ? 10'd420 :
                            in_heart1 ? 10'd380 :
                            in_heart2 ? 10'd340 :
                                        10'd300;

wire [23:0] lives_raw_color;
life_display life_display_render(
    .x(x),
    .y(y),
    .active_pixels(active_pixels && (in_heart0 || in_heart1 || in_heart2 || in_heart3)),
    .heart_x_pos(10'd609),
    .heart_y_pos(active_heart_y),
    .color(lives_raw_color)
);

wire [23:0] active_goomba_color = goomba_is_scared ? scared_goomba_color : goomba_color;
wire [23:0] active_shy_guy_color = goomba_is_scared ? scared_goomba_color : shy_guy_color; // todo: use scared_shy_guy_color here once that sprite is done

wire [23:0] blinky_display_color = blinky_is_frightened ? scared_raw_color : blinky_raw_color;
wire [23:0] pinky_display_color  = pinky_is_frightened  ? scared_raw_color : pinky_raw_color;
wire [23:0] inky_display_color   = inky_is_frightened   ? scared_raw_color : inky_raw_color;
wire [23:0] clyde_display_color  = clyde_is_frightened  ? scared_raw_color : clyde_raw_color;

wire show_pacman = player_visible && (final_player_color != 24'h000000);
wire show_goomba = easter_egg1_active && (active_goomba_color != 24'h000000);
wire show_shy_guy = easter_egg2_active && (active_shy_guy_color != 24'h000000);
wire show_blinky = !any_easter_egg && (blinky_display_color != 24'h000000);
wire show_pinky  = !any_easter_egg && (pinky_display_color  != 24'h000000);
wire show_inky   = !any_easter_egg && (inky_display_color   != 24'h000000);
wire show_clyde  = !any_easter_egg && (clyde_display_color  != 24'h000000);
wire show_lives  = (lives_raw_color != 24'h000000);

wire [23:0] final_vga_color = show_pacman  ? final_player_color :
                              show_goomba  ? active_goomba_color :
                              show_shy_guy ? active_shy_guy_color :
                              show_blinky  ? blinky_display_color :
                              show_pinky   ? pinky_display_color :
                              show_inky    ? inky_display_color :
                              show_clyde   ? clyde_display_color :
                              show_lives   ? lives_raw_color :
                                             {fb_r, fb_g, fb_b};
														  
assign VGA_R = final_vga_color[23:16];
assign VGA_G = final_vga_color[15:8];
assign VGA_B = final_vga_color[7:0];

								 
//ghost scared state flashes near end of frightened timer (1.5 seconds)

reg [9:0] draw_x;
reg [9:0] draw_y;


//key latching & movement helper

reg started;

//regulating ghost speed and entity freezes upon ghost death
reg [5:0] freeze_timer;
wire frame_tick = (S == MOVE) && (freeze_timer == 6'd0);


//fsm parameters
reg [3:0]S;
reg [3:0]NS;

parameter START       = 3'd0,
			 CLEAR       = 3'd1,
			 WAIT        = 3'd2,
			 SYNC_LOW    = 3'd3, //prevent white flashes while moving, waits for screen to stop scanning until render next frame
			 MOVE        = 3'd4,
			 DRAW_WALL   = 3'd5,
			 SYNC_HIGH   = 3'd6, //waits for screen to start scanning
			 GAME_OVER   = 3'd7;

			
			
//joystick wires
wire joy_up = KEY[0] && GPIO_0[0];
wire joy_down = KEY[3] && GPIO_0[1];
wire joy_left =  KEY[1] && GPIO_0[2];
wire joy_right = KEY[2] && GPIO_0[3];

//key latching logic
always @(posedge clk or negedge rst) begin
    if (!rst) begin
        direction <= 2'b00;
        started   <= 1'b0;
    end else if (death_timer > 7'd0 || game_over_active || game_won_active || level_transition || (level_clear_timer > 7'd0)) begin
        started   <= 1'b0; // locks input during the 2 second death freeze or game over
        direction <= 2'b00;
    end else begin
        if (joy_up == 1'b0) begin
            started <= 1'b1;
            if (!wall_above) direction <= 2'b00;
        end else if (joy_down == 1'b0) begin
            started <= 1'b1;
            if (!wall_below) direction <= 2'b01;
        end else if (joy_left == 1'b0) begin
            started <= 1'b1;
            if (!wall_left) direction <= 2'b10;
        end else if (joy_right == 1'b0) begin
            started <= 1'b1;
            if (!wall_right) direction <= 2'b11;
        end
    end
end


// fsm state cases
always @(posedge clk or negedge rst)
begin	
	if (rst == 1'b0)
		S <= START;
	else
		S <= NS;
end 	

always @(*) begin
	case (S)
		START:     NS = CLEAR;
		CLEAR:     NS = (idx_location == 15'd19199) ? DRAW_WALL : CLEAR;
		WAIT:      NS = SYNC_LOW;
		SYNC_LOW:  NS = (VGA_VS == 1'b0) ? MOVE : SYNC_LOW;
		MOVE:      NS = DRAW_WALL;
		DRAW_WALL: NS = ((draw_x == 10'd7) && (draw_y == 10'd7) && (tile_x_idx == 5'd19) && (tile_y_idx == 4'd14)) ? ((game_over_active || game_won_active) ? GAME_OVER : SYNC_HIGH) : DRAW_WALL;
		SYNC_HIGH: NS = (VGA_VS == 1'b1) ? WAIT : SYNC_HIGH;
		GAME_OVER: NS = GAME_OVER;
		default:   NS = START;
	endcase
end	


// fsm functions cases
always @ (posedge clk or negedge rst)
begin
	if (rst == 1'b0) begin
		the_vga_draw_frame_write_mem_address <= 15'd0;
		the_vga_draw_frame_write_mem_data <= 24'd0;
		the_vga_draw_frame_write_a_pixel <= 1'b0;
		
		blinky_respawn_timer <= 8'd0;
		pinky_respawn_timer <= 8'd0;
		inky_respawn_timer <= 8'd0;
		clyde_respawn_timer <= 8'd0;
		
		level <= 1'b0;
		level_transition <= 1'b0;
		level_clear_timer <= 7'd0;
		saved_pellets_eaten <= 13'd0;
		saved_super_pellets_eaten <= 13'd0;
	   saved_ghost_score <= 16'd0;
	
		draw_x <= 10'd0; //resets values
		draw_y <= 10'd0;
		idx_location <= 15'd0;
			
		pacman_x_pos <= 10'd128;
		pacman_y_pos <= 10'd56; 
			
		tile_x_idx <= 5'd0;
		tile_y_idx <= 4'd0;
		
		eaten_pellet <= 300'd0;
		pellets_eaten <= 13'd0; // counter
		
		eaten_super_pellet <= 300'd0;
		super_pellets_eaten <= 13'd0; //counter
		super_pellet_blink_counter <= 5'd0;
		
		stagger_timer <= 8'd0;
		freeze_timer <= 6'd0;
		easter_egg1_active <= 1'b0;
		easter_egg2_active <= 1'b0;
		
		lives <= 3'd3;
		game_over_active <= 1'b0;
		death_timer <= 7'd0;
		game_won_active <= 1'b0;
		
		active_pellet <= 1'b0;
		pellet1_ghost_count <= 13'd0;
		pellet2_ghost_count <= 13'd0;
		en_pellet1 <= 1'b0;
		en_pellet2 <= 1'b0;
		
		blinky_scared <= 1'b0;
		pinky_scared <= 1'b0;
		inky_scared <= 1'b0;
		clyde_scared <= 1'b0;
		
		ghost_anim_timer <= 4'd0;
		ghost_anim_frame <= 2'b00;

	end
	else begin
		the_vga_draw_frame_write_a_pixel <= 1'b0;
		en_pellet1 <= 1'b0;
		en_pellet2 <= 1'b0;
		if (S != DRAW_WALL) begin
			draw_x <= 10'd0;
			draw_y <= 10'd0; end
		case(S)
			START: 
			begin	
				idx_location <= 15'd0; //resets values
			end

			CLEAR: begin
				the_vga_draw_frame_write_mem_address <= idx_location; // paints pixels over black
				the_vga_draw_frame_write_mem_data <= 24'h000000;   
				the_vga_draw_frame_write_a_pixel <= 1'b1;
				idx_location <= idx_location + 1'b1;
			end

			MOVE: begin
					tile_x_idx <= 5'd0;
					tile_y_idx <= 4'd0;
					level_transition <= 1'b0;
					
					if(super_pellet_blink_counter == 5'd29)
						  super_pellet_blink_counter <= 5'd0;
					else
						  super_pellet_blink_counter <= super_pellet_blink_counter + 1'b1;
					
					if (eat_blinky) begin 
						blinky_respawn_timer <= 8'd180; 
						blinky_scared <= 1'b0; 
						freeze_timer <= 6'd60; 
					end
						
					if (eat_pinky) begin 
						pinky_respawn_timer <= 8'd180; 
						pinky_scared <= 1'b0; 
						freeze_timer <= 6'd60; 
					end
						
					if (eat_inky) begin 
						inky_respawn_timer <= 8'd180; 
						inky_scared <= 1'b0; 
						freeze_timer <= 6'd60; 
					end
						
					if (eat_clyde) begin 
						clyde_respawn_timer <= 8'd180; 
						clyde_scared <= 1'b0; 
						freeze_timer <= 6'd60; 
					end
						
					// pulse ghost score reg 
					if (ghosts_eaten_now > 3'd0) begin
						 if (active_pellet == 1'b0) begin
							  if (pellet1_ghost_count < 13'd4) begin
									pellet1_ghost_count <= ((pellet1_ghost_count + {10'd0, ghosts_eaten_now}) > 13'd4) ? 13'd4 : (pellet1_ghost_count + {10'd0, ghosts_eaten_now});
									en_pellet1 <= 1'b1;
							  end
						 end else begin
							  if (pellet2_ghost_count < 13'd4) begin
									pellet2_ghost_count <= ((pellet2_ghost_count + {10'd0, ghosts_eaten_now}) > 13'd4) ? 13'd4 : (pellet2_ghost_count + {10'd0, ghosts_eaten_now});
									en_pellet2 <= 1'b1;
							  end
						 end
					end
				
					if ((pellet1_ghost_count == 13'd4 || pellet2_ghost_count == 13'd4) && (level_clear_timer == 7'd0)) begin
						if (level == 1'b0)
								easter_egg1_active <= 1'b1;
						else
								easter_egg2_active <= 1'b1;
						end															

					if(freeze_timer > 6'd0) begin
						freeze_timer <= freeze_timer - 1'b1; 
					end else begin
						if(!eaten_pellet[eat_idx] && !no_pellet) begin
							eaten_pellet[eat_idx] <= 1'b1;
							pellets_eaten <= pellets_eaten + 1'b1; 
						end
					
						if(!eaten_super_pellet[eat_idx] && is_super_pellet) begin
							eaten_super_pellet[eat_idx] <= 1'b1;
							super_pellets_eaten <= super_pellets_eaten + 1'b1;
							frightened_timer <= 9'd360;
							  
							blinky_scared <= blinky_release_sig && !blinky_eaten;
							pinky_scared <= pinky_release_sig && !pinky_eaten;
							inky_scared <= inky_release_sig && !inky_eaten;
							clyde_scared <= clyde_release_sig && !clyde_eaten;
						  
							if (is_pellet1) active_pellet <= 1'b0;
							else if (is_pellet2) active_pellet <= 1'b1;
						end
					
						if ((pellets_eaten + super_pellets_eaten) >= current_total_pellets) begin
							if (level == 1'b0) begin
								if (level_clear_timer == 7'd0) begin
									level_clear_timer <= 7'd95;
								end
							end else begin
								// win within level 2
								game_won_active <= 1'b1;
							end
						end

						if (frightened_timer > 9'd0) begin
							frightened_timer <= frightened_timer - 1'b1;
							if (frightened_timer == 9'd1) begin
								blinky_scared <= 1'b0;
								pinky_scared <= 1'b0;
								inky_scared <= 1'b0;
								clyde_scared <= 1'b0;
							end
						end
					
						if (blinky_respawn_timer > 8'd0) blinky_respawn_timer <= blinky_respawn_timer - 1'b1;
						if (pinky_respawn_timer > 8'd0) pinky_respawn_timer <= pinky_respawn_timer - 1'b1;
						if (inky_respawn_timer > 8'd0) inky_respawn_timer <= inky_respawn_timer - 1'b1;
						if (clyde_respawn_timer > 8'd0) clyde_respawn_timer <= clyde_respawn_timer - 1'b1;

						if (!started || game_over_active || game_won_active || (level_clear_timer > 7'd0)) begin
							stagger_timer <= 8'd0;
						end else if (stagger_timer < 8'd120) begin
							stagger_timer <= stagger_timer + 1'b1;
						end

						if (level_clear_timer > 7'd1) begin
							level_clear_timer <= level_clear_timer - 1'b1;
						end else if (level_clear_timer == 7'd1 || (SW_db[0] && !level)) begin
							level_clear_timer <= 7'd0;
							level <= 1'b1;
							easter_egg2_active <= 1'b0;
							level_transition <= 1'b1;
							easter_egg1_active <= 1'b0;
							lives <= lives + 1'b1;
								
							// saves score from level 1
							saved_pellets_eaten <= pellets_eaten;
							saved_super_pellets_eaten <= super_pellets_eaten;
							saved_ghost_score <= total_ghost_score;

							// resets board and entities for level 2
							eaten_pellet <= 300'd0;
							eaten_super_pellet <= 300'd0;
							pellets_eaten <= 13'd0;
							super_pellets_eaten <= 13'd0;
							pellet1_ghost_count <= 13'd0;
							pellet2_ghost_count <= 13'd0;

							pacman_x_pos <= 10'd128;
							pacman_y_pos <= 10'd56;
							frightened_timer <= 9'd0;
							stagger_timer <= 8'd0;

							blinky_scared <= 1'b0;
							pinky_scared <= 1'b0;
							inky_scared <= 1'b0;
							clyde_scared <= 1'b0;
							blinky_respawn_timer <= 8'd0;
							pinky_respawn_timer <= 8'd0;
							inky_respawn_timer <= 8'd0;
							clyde_respawn_timer <= 8'd0;
						end else if (death_timer > 7'd1) begin
							death_timer <= death_timer - 1'b1;
						end else if (death_timer == 7'd1) begin
							death_timer <= 7'd0;
							pacman_x_pos <= 10'd128;
							pacman_y_pos <= 10'd56;
							stagger_timer <= 8'd0;
							  
							blinky_scared <= 1'b0;
							pinky_scared <= 1'b0;
							inky_scared <= 1'b0;
							clyde_scared <= 1'b0;
							  
							if(lives == 3'd0) begin
								game_over_active <= 1'b1; 
							end
						end else if (pacman_die_collision && !game_over_active) begin
							death_timer <= 7'd120;
							stagger_timer <= 8'd0;
							if (lives > 3'd0) begin
								lives <= lives - 1'b1; 
							end 
						end else if (started && !game_over_active) begin
							case(direction)
								2'b00: if((pacman_y_pos > 0) && !wall_above)
											pacman_y_pos <= (pacman_y_pos - 1'b1);
													
								2'b01: if(((pacman_y_pos + PACMAN_SIZE) < (VIRTUAL_PIXEL_HEIGHT - 1'b1)) && !wall_below)
											pacman_y_pos <= (pacman_y_pos + 1'b1);
													
								2'b10: if((pacman_x_pos > 0) && !wall_left)
											pacman_x_pos <= (pacman_x_pos - 1'b1);
													
								2'b11: if(((pacman_x_pos + PACMAN_SIZE) < (VIRTUAL_PIXEL_WIDTH - 1'b1)) && !wall_right) 													
											pacman_x_pos <= (pacman_x_pos + 1'b1);
							endcase

							if (pacman_y_pos == 1'b0)
								pacman_y_pos <= (VIRTUAL_PIXEL_HEIGHT - PACMAN_SIZE - 2'b10);
							else if (pacman_y_pos == (VIRTUAL_PIXEL_HEIGHT - PACMAN_SIZE - 1'b1))
								pacman_y_pos <= 1'b1;
						end

						if (started && !game_over_active && (death_timer == 7'd0)) begin
							pacman_anim_timer <= pacman_anim_timer + 1'b1;
						end else begin
							pacman_anim_timer <= 5'd0; // mouth closed when not moving
						end

						if (started && !game_over_active && (freeze_timer == 6'd0)) begin
							if (ghost_anim_timer == 4'd15) begin
								ghost_anim_timer <= 4'd0;
								if (ghost_anim_frame == 2'b10)
									ghost_anim_frame <= 2'b00;
								else
									ghost_anim_frame <= ghost_anim_frame + 1'b1;
							end else begin
								ghost_anim_timer <= ghost_anim_timer + 1'b1;
							end
						end
					end
			end				
			
			DRAW_WALL: begin
					the_vga_draw_frame_write_mem_address <= (({11'd0, tile_x_idx} * 16'd8 + {6'd0, draw_x}) * VIRTUAL_PIXEL_HEIGHT) + ({12'd0, tile_y_idx} * 16'd8 + {6'd0, draw_y});				  
					
					if (game_over_color != 24'h000000) begin
						the_vga_draw_frame_write_mem_data <= game_over_color;
					end else if (game_won_color != 24'h000000) begin
						the_vga_draw_frame_write_mem_data <= game_won_color;
					end else begin
						the_vga_draw_frame_write_mem_data <= (is_gate_bar ? 24'hFFB8FF :
                                     (is_wall_border ? wall_border_color :
                                     (is_wall_fill ? wall_fill_color : 
                                     (draw_pellet ? pellet_color :
                                     (draw_super_pellet ? (level ? 24'hFFFFFF : 24'hFFB8AE) : 24'h000000))))); end
					
					the_vga_draw_frame_write_a_pixel <= 1'b1;
						
					if (draw_x < 10'd7) begin
						draw_x <= draw_x + 1'b1;  // sweeps pixels of each tile x0-x7 
					end else begin
						draw_x <= 10'd0;
						if (draw_y < 10'd7) begin
							draw_y <= draw_y + 1'b1; // sweeps pixels of each tile y0-y7
						end else begin
							draw_y <= 10'd0;		
							if (tile_x_idx < 5'd19) begin
								tile_x_idx <= tile_x_idx + 1'b1; // sweeps tile x across screen 0-19 
							end else begin
								tile_x_idx <= 5'd0;
								if (tile_y_idx < 4'd14) begin
									tile_y_idx <= tile_y_idx + 1'b1; // sweeps tile y down the screen 0-14 
								end else begin
									tile_y_idx <= 4'd0;
								end
							end
						end
					end
				end
		default: ;	
		endcase
	end
end

three_decimal_vals_w_neg my_three_decimal_vals_w_neg(saved_pellets_eaten + pellets_eaten, saved_super_pellets_eaten + super_pellets_eaten, saved_ghost_score + total_ghost_score, HEX4, HEX3, HEX2, HEX1, HEX0);
endmodule