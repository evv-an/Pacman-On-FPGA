module vga_driver_to_frame_buf(
	output [6:0]HEX0,
	output [6:0]HEX1,
	output [6:0]HEX2,
	output [6:0]HEX3,
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
	.VGA_B(VGA_B),
	.VGA_G(VGA_G),
	.VGA_R(VGA_R),
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


// draws a line of blue on wall borders that are touching path OR gate tile
wire is_top_border = ((draw_y == 10'd0) && !wall_above_render) || ((draw_y == 10'd0) && below_gate);
wire is_bottom_border = ((draw_y == 10'd7) && !wall_below_render) || ((draw_y == 10'd7) && above_gate);
wire is_left_border = (draw_x == 10'd0) && !wall_left_render;
wire is_right_border = (draw_x == 10'd7) && !wall_right_render;
wire is_wall_border = !is_gate_tile && (is_draw_wall && (is_top_border || is_bottom_border || is_left_border || is_right_border));
wire is_corner = ((draw_x == 10'd0 || draw_x == 10'd7) && (draw_y == 10'd0 || draw_y == 10'd7));


// variables for respawn & lives function
reg [1:0] lives;
reg game_over_active;
reg game_won_active; 
reg [6:0] death_timer;

// onscreen life counter drawing
reg [1:0]lives_idx;
wire [23:0]lives_raw_color;
wire [9:0] lives_x = 10'd153;
wire [9:0] lives_y = 10'd105 - ({8'd0, lives_idx} * 10'd10);
life_display life_display_render(
    .draw_x(draw_x[2:0]),
    .draw_y(draw_y[2:0]),
    .color(lives_raw_color));


//pacman drawing & animations
wire [23:0] raw_pacman_color;
reg [4:0] pacman_anim_timer;
wire [1:0] anim_frame = pacman_anim_timer[4:3];
pacman_sprite pacman_render(
    .draw_x(draw_x[2:0]),
    .draw_y(draw_y[2:0]),
    .direction(direction),
	 .anim_frame(anim_frame),
    .color(raw_pacman_color));

wire player_visible = (death_timer == 7'd0) || death_timer[3];
wire [23:0] active_player_color = easter_egg_active ? mario_color : raw_pacman_color;
wire [23:0] final_player_color  = player_visible ? active_player_color : 24'h000000;

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
	 
//easter egg stuff
wire [23:0] mario_color;
mario_sprite mario_render_inst(
    .draw_x(draw_x[2:0]),
    .draw_y(draw_y[2:0]),
    .direction(direction),
    .color(mario_color)
);

wire [23:0] goomba_color;
goomba_sprite goomba_render_inst(
    .draw_x(draw_x[2:0]),
    .draw_y(draw_y[2:0]),
    .anim_frame(ghost_anim_frame),
    .is_scared(active_is_frightened),
    .color(goomba_color)
);



//pellet system logic & registers 
parameter TOTAL_PELLETS = 13'd116; //116 pellets (114+2)
reg [299:0] eaten_pellet;
reg [12:0] pellets_eaten; //counter
reg [12:0] super_pellets_eaten; //counter
reg [299:0] eaten_super_pellet;
reg [4:0] super_pellet_blink_counter;

wire[4:0] pacman_center_tile_x = (pacman_x_pos + 10'd4) >> 3; //knows when pacman hits center of tile
wire[3:0] pacman_center_tile_y = (pacman_y_pos + 10'd4) >> 3; 

wire[8:0] eat_idx = (pacman_center_tile_y * 5'd20) + (5'd19 - pacman_center_tile_x); //tracks pacman tile index for eating while moving
wire[8:0] draw_idx = (tile_y_idx * 5'd20) + (5'd19 - tile_x_idx);							 //tracks tile index being scanned by vga renderer

//game logic: locations pellets cannot spawn (ranges of tiles)
wire warp_hallway = (pacman_center_tile_x == 5'd9) && (pacman_center_tile_y <= 4'd1 || pacman_center_tile_y >= 4'd13 || pacman_center_tile_y == 4'd3 || pacman_center_tile_y == 4'd11);
wire ghost_cage = (pacman_center_tile_x >= 5'd6 && pacman_center_tile_x <= 5'd12) && (pacman_center_tile_y >= 4'd4 && pacman_center_tile_y <= 4'd10);
wire spawn_tile = ((pacman_center_tile_x == 5'd16) && (pacman_center_tile_y == 4'd7)) || ((pacman_center_tile_x == 5'd5) && (pacman_center_tile_y == 4'd1)) || ((pacman_center_tile_x == 5'd13) && (pacman_center_tile_y == 4'd13));
wire no_pellet = warp_hallway || ghost_cage || spawn_tile;

//vga logic: locations pellets cannot spawn (ranges of tiles)
wire draw_is_warp_hallway = (tile_x_idx == 5'd9) && (tile_y_idx <= 4'd1 || tile_y_idx >= 4'd13 || tile_y_idx == 4'd3 || tile_y_idx == 4'd11);
wire draw_is_ghost_cage = (tile_x_idx >= 5'd6 && tile_x_idx <= 5'd12) && (tile_y_idx >= 4'd4 && tile_y_idx <= 4'd10);
wire draw_is_spawn_tile = ((tile_x_idx == 5'd16) && (tile_y_idx == 4'd7)) || ((tile_x_idx == 5'd5) && (tile_y_idx == 4'd1)) || ((tile_x_idx == 5'd13) && (tile_y_idx == 4'd13));
wire draw_no_pellet = draw_is_warp_hallway || draw_is_ghost_cage || draw_is_spawn_tile;

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
    .rst(rst),
    .en(en_pellet1),
    .ghost_count(pellet1_ghost_count),
    .ghost_score(pellet1_score_out)
);

ghost_reg pellet2_score_reg (
    .clk(clk),
    .rst(rst),
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
tilemap_rom tile_up_l(
	.tile_x(curr_tile_x_left),
	.tile_y(next_tile_y_top),
	.is_wall(w_up_l));

tilemap_rom tile_up_r(
	.tile_x(curr_tile_x_right),
	.tile_y(next_tile_y_top),
	.is_wall(w_up_r));

tilemap_rom tile_dn_l(
	.tile_x(curr_tile_x_left),
	.tile_y(next_tile_y_bottom),
	.is_wall(w_dn_l));

tilemap_rom tile_dn_r(
	.tile_x(curr_tile_x_right),
	.tile_y(next_tile_y_bottom),
	.is_wall(w_dn_r));

tilemap_rom tile_lt_t(
	.tile_x(next_tile_x_left),
	.tile_y(curr_tile_y_top),
	.is_wall(w_lt_t));

tilemap_rom tile_lt_b(
	.tile_x(next_tile_x_left),
	.tile_y(curr_tile_y_bottom),
	.is_wall(w_lt_b));

tilemap_rom tile_rt_t(
	.tile_x(next_tile_x_right),
	.tile_y(curr_tile_y_top),
	.is_wall(w_rt_t));

tilemap_rom tile_rt_b(
	.tile_x(next_tile_x_right),
	.tile_y(curr_tile_y_bottom),
	.is_wall(w_rt_b));

	
// tile logic (1:wall, 0:path)
reg [4:0] tile_x_idx; // 0 to 19 (8x8 pixel tiles)
reg [3:0] tile_y_idx; // 0 to 14
wire is_draw_wall;

tilemap_rom map_render(
    .tile_x(tile_x_idx),
    .tile_y(tile_y_idx),
    .is_wall(is_draw_wall));

	 
// detects walls around path tiles				
wire wall_above_render;
wire wall_below_render;
wire wall_left_render;
wire wall_right_render;

tilemap_rom map_up(
	.tile_x(tile_x_idx),
	.tile_y((tile_y_idx > 0) ? (tile_y_idx - 1'b1) : 4'd0),
	.is_wall(wall_above_render));

tilemap_rom map_dn(
	.tile_x(tile_x_idx),
	.tile_y((tile_y_idx < 4'd14) ? (tile_y_idx + 1'b1) : 4'd14),
	.is_wall(wall_below_render));

tilemap_rom map_lt(
	.tile_x((tile_x_idx > 0) ? (tile_x_idx - 1'b1) : 5'd0),
	.tile_y(tile_y_idx),
	.is_wall(wall_left_render));

tilemap_rom map_rt (
	.tile_x((tile_x_idx < 5'd19) ? (tile_x_idx + 1'b1) : 5'd19),
	.tile_y(tile_y_idx),
	.is_wall(wall_right_render));

	
//pacman location & size
reg[9:0] pacman_x_pos;
reg[9:0] pacman_y_pos;
parameter PACMAN_SIZE = 10'd8; //dimensions of pacman (also tile length and width)


//ghost frightened stage logic
wire ghost_rst = rst && !(death_timer == 7'd1);
reg [8:0] frightened_timer; // 360 frames = 6 seconds at 60hz
wire is_frightened = (frightened_timer > 9'd0); 


//scared ghost drawing
wire [23:0] scared_raw_color;

scared_ghost_sprite scared_render_inst(
    .draw_x(draw_x[2:0]),
    .draw_y(draw_y[2:0]),
    .flash(frightened_timer < 9'd90 && super_pellet_blink_counter[3]),
    .color(scared_raw_color)
);

//ghost feet animations
reg [3:0] ghost_anim_timer;
reg [1:0] ghost_anim_frame;
reg easter_egg_active;


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
wire [4:0] pacman_tile_x = pacman_x_pos >> 3;
wire [3:0] pacman_tile_y = pacman_y_pos >> 3;

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
    .release_signal(clyde_release_sig),
    .spawn_x(10'd72), .spawn_y(10'd48),
    .release_x(10'd56), .release_y(10'd56),
    .initial_direction(2'b00),
    .frame_tick(frame_tick),
    .target_tile_x(clyde_target_x), .target_tile_y(clyde_target_y),
    .speed_mask(2'b11),
    .ghost_x_pos(clyde_x_pos), .ghost_y_pos(clyde_y_pos), .ghost_direction(clyde_dir)
);

reg [1:0] ghost_select;

reg [9:0]  active_ghost_x;    
reg [9:0]  active_ghost_y;
reg [1:0]  active_ghost_dir;   
reg [23:0] active_body_color;

always @(*) begin
    case (ghost_select)
        2'b00: begin //blinky
            active_ghost_x = blinky_x_pos;
            active_ghost_y = blinky_y_pos;
            active_ghost_dir = blinky_dir;
            active_body_color = 24'hFF0000;
        end
        2'b01: begin //pinky
            active_ghost_x = pinky_x_pos;
            active_ghost_y = pinky_y_pos;
            active_ghost_dir = pinky_dir;
            active_body_color = 24'hFFB8FF;
        end
        2'b10: begin //inky
            active_ghost_x = inky_x_pos;
            active_ghost_y = inky_y_pos;
            active_ghost_dir = inky_dir;
            active_body_color = 24'h00FFFF;
        end
        2'b11: begin //clyde
            active_ghost_x = clyde_x_pos;
            active_ghost_y = clyde_y_pos;
            active_ghost_dir = clyde_dir;
            active_body_color = 24'hFFB852;
        end
    endcase
end


//individual ghost color wires
wire [23:0] blinky_raw_color;
wire [23:0] pinky_raw_color;
wire [23:0] inky_raw_color;
wire [23:0] clyde_raw_color;


//ghost coloring instantiations (ghostname_sprite.v)
blinky_sprite blinky_render_inst(
    .draw_x(draw_x[2:0]),
    .draw_y(draw_y[2:0]),
    .direction(active_ghost_dir),
    .anim_frame(ghost_anim_frame),
    .color(blinky_raw_color)
);

pinky_sprite pinky_render_inst(
    .draw_x(draw_x[2:0]),
    .draw_y(draw_y[2:0]),
    .direction(active_ghost_dir),
    .anim_frame(ghost_anim_frame),
    .color(pinky_raw_color)
);

inky_sprite inky_render_inst(
    .draw_x(draw_x[2:0]),
    .draw_y(draw_y[2:0]),
    .direction(active_ghost_dir),
    .anim_frame(ghost_anim_frame),
    .color(inky_raw_color)
);

clyde_sprite clyde_render_inst(
    .draw_x(draw_x[2:0]),
    .draw_y(draw_y[2:0]),
    .direction(active_ghost_dir),
    .anim_frame(ghost_anim_frame),
    .color(clyde_raw_color)
);

//checks if ghost is currently scared or eaten
wire active_is_eaten = (ghost_select == 2'b00 && blinky_eaten) || (ghost_select == 2'b01 && pinky_eaten) || (ghost_select == 2'b10 && inky_eaten) || (ghost_select == 2'b11 && clyde_eaten);
							  
wire active_is_frightened = (ghost_select == 2'b00 && blinky_is_frightened) || (ghost_select == 2'b01 && pinky_is_frightened) || (ghost_select == 2'b10 && inky_is_frightened) ||(ghost_select == 2'b11 && clyde_is_frightened);

									 
//ghost scared state flashes near end of frightened timer (1.5 seconds)
wire [23:0] scared_color = (frightened_timer < 9'd90 && super_pellet_blink_counter[3]) ? 24'hFFFFFF : 24'h0000FF;

reg [23:0] raw_ghost_color;
always @(*) begin
    case (ghost_select)
        2'b00: raw_ghost_color = blinky_raw_color;
        2'b01: raw_ghost_color = pinky_raw_color;
        2'b10: raw_ghost_color = inky_raw_color;
        2'b11: raw_ghost_color = clyde_raw_color;
        default: raw_ghost_color = 24'h000000;
    endcase
end

reg [23:0] final_ghost_color;
always @(*) begin
    if (easter_egg_active) begin
        final_ghost_color = goomba_color;
    end else if (active_is_eaten) begin
        final_ghost_color = raw_ghost_color;
    end else if (active_is_frightened) begin
        final_ghost_color = scared_raw_color;
    end else begin
        final_ghost_color = raw_ghost_color;
    end
end


reg [9:0] draw_x;
reg [9:0] draw_y;


//key latching & movement helpers
reg [1:0] direction;
reg started;


//regulating ghost speed and entity freezes upon ghost death
reg [5:0] freeze_timer;
wire frame_tick = (S == MOVE) && (freeze_timer == 6'd0);


//fsm parameters
reg [3:0]S;
reg [3:0]NS;

parameter START       = 4'b0000,
			 CLEAR       = 4'b0001,
			 WAIT        = 4'b0010,
			 SYNC_LOW    = 4'b0011, //prevent white flashes while moving, waits for screen to stop scanning until render next frame
			 ERASE       = 4'b0100,
			 MOVE        = 4'b0101,
			 COLOR       = 4'b0110,
			 DRAW_WALL   = 4'b0111,
			 SYNC_HIGH   = 4'b1000, //waits for screen to start scanning
			 COLOR_GHOST = 4'b1001,
			 GAME_OVER   = 4'b1010,
			 DRAW_LIVES  = 4'b1011;
			
			
//joystick wires
wire joy_up = KEY[2] && GPIO_0[0];
wire joy_down = KEY[1] && GPIO_0[1];
wire joy_left =  KEY[3] && GPIO_0[2];
wire joy_right = KEY[0] && GPIO_0[3];

//key latching logic
always @(posedge clk or negedge rst) begin
    if (!rst) begin
        direction <= 2'b00;
        started   <= 1'b0;
    end else if (death_timer > 7'd0 || game_over_active || game_won_active) begin
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

always @(*)
begin
	case(S)
		START: NS = CLEAR;
			
		CLEAR:
		begin
			if(idx_location == 15'd19199) // total # of pixels on screen
				NS = DRAW_WALL;
			else
				NS = CLEAR;
		end
			
		WAIT:	NS = SYNC_LOW;
			
		SYNC_LOW: 
		begin
			if(VGA_VS == 1'b0) // waits for vertical sync
				NS = ERASE;
			else
				NS = SYNC_LOW;
		end

		ERASE:
		begin
			if ((draw_x == PACMAN_SIZE - 1) && (draw_y == PACMAN_SIZE -1))
				NS = MOVE;
			else
				NS = ERASE;
		end

		MOVE: NS = DRAW_WALL;

		COLOR: 
		begin	
			if ((draw_x == PACMAN_SIZE - 1) && (draw_y == PACMAN_SIZE - 1))
				NS = COLOR_GHOST;
			else
				NS = COLOR;
		end
		
		COLOR_GHOST:
		begin
			if ((draw_x == PACMAN_SIZE - 1) && (draw_y == PACMAN_SIZE - 1) && (ghost_select == 2'b11))
				NS = DRAW_LIVES;
			else
				NS = COLOR_GHOST;
		end
		
		DRAW_LIVES: 
		begin
			if ((draw_x == 10'd5) && (draw_y == 10'd7) && (lives_idx == 2'd2))
				NS = (game_over_active || game_won_active) ? GAME_OVER : SYNC_HIGH;
			else
				NS = DRAW_LIVES;
		end

		DRAW_WALL:
		begin 
			if ((draw_x == 10'd7) && (draw_y == 10'd7) && (tile_x_idx == 5'd19) && (tile_y_idx == 4'd14))
				NS = COLOR;
			else
				NS = DRAW_WALL;
		end

		SYNC_HIGH:
		begin
			if (VGA_VS == 1'b1)
				NS = WAIT;
			else
				NS = SYNC_HIGH;
		end
		
		GAME_OVER: NS = GAME_OVER;

		default: NS = START;
	endcase
end	


// fsm functions cases
always @ (posedge clk or negedge rst)
begin
	if (rst == 1'b0)
	begin
		the_vga_draw_frame_write_mem_address <= 15'd0;
		the_vga_draw_frame_write_mem_data <= 24'd0;
		the_vga_draw_frame_write_a_pixel <= 1'b0;
	
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
		easter_egg_active <= 1'b0;
		
		ghost_select <= 1'b0;
		
		lives <= 2'd3;
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
		case(S)
			START: 
			begin	
				idx_location <= 15'd0; //resets values
				the_vga_draw_frame_write_a_pixel <= 1'b0;
			end

			CLEAR:
			begin
				the_vga_draw_frame_write_mem_address <= idx_location; // paints pixels over black
				the_vga_draw_frame_write_mem_data <= 24'h000000;   
				the_vga_draw_frame_write_a_pixel <= 1'b1;
				idx_location <= idx_location + 1'b1;
			end

			WAIT:
			begin
				the_vga_draw_frame_write_a_pixel <= 1'b0; //resets draw signals while waiting so stages don't overlap
				draw_x <= 10'd0;
				draw_y <= 10'd0;
				ghost_select <= 1'b0;
				en_pellet1 <= 1'b0;
				en_pellet2 <= 1'b0;
			end
				
			SYNC_LOW:
			begin
				the_vga_draw_frame_write_a_pixel <= 1'b0; 
			end

			ERASE: 
			begin
				the_vga_draw_frame_write_mem_address <= ((pacman_x_pos + draw_x) * VIRTUAL_PIXEL_HEIGHT) + (pacman_y_pos + draw_y); 
				the_vga_draw_frame_write_mem_data <= 24'h000000;
				the_vga_draw_frame_write_a_pixel <= 1'b1;
					
				if(draw_x < PACMAN_SIZE - 1)
					draw_x <= draw_x + 1'b1; //loop to draw old box location
				else
				begin
					draw_x <= 10'd0;
						
				if(draw_y < PACMAN_SIZE - 1)
					draw_y <= draw_y + 1'b1;
				end
			end

			MOVE:
			begin
					draw_x <= 10'd0;
					draw_y <= 10'd0;
					the_vga_draw_frame_write_a_pixel <= 1'b0;
					tile_x_idx <= 5'd0;
					tile_y_idx <= 4'd0;
					
					en_pellet1 <= 1'b0;
					en_pellet2 <= 1'b0;
					
					if(super_pellet_blink_counter == 5'd29)
						  super_pellet_blink_counter <= 5'd0;
					else
						  super_pellet_blink_counter <= super_pellet_blink_counter + 1'b1;
					
					if (eat_blinky) begin 
						blinky_respawn_timer <= 8'd180; 
						blinky_scared <= 1'b0; 
						freeze_timer <= 6'd60; end
						
					if (eat_pinky) begin 
						pinky_respawn_timer <= 8'd180; 
						pinky_scared <= 1'b0; 
						freeze_timer <= 6'd60; end
						
					if (eat_inky) begin 
						inky_respawn_timer <= 8'd180; 
						inky_scared <= 1'b0; 
						freeze_timer <= 6'd60; end
						
					if (eat_clyde) begin 
						clyde_respawn_timer <= 8'd180; 
						clyde_scared <= 1'b0; 
						freeze_timer <= 6'd60; end
						
						
					// pulse ghost score reg 
					if (eat_blinky || eat_pinky || eat_inky || eat_clyde) begin
						if (active_pellet == 1'b0) begin
							if (pellet1_ghost_count < 13'd4) begin
								pellet1_ghost_count <= pellet1_ghost_count + 1'b1;
								en_pellet1 <= 1'b1;
							end
						end else begin
							if (pellet2_ghost_count < 13'd4) begin
								pellet2_ghost_count <= pellet2_ghost_count + 1'b1;
								en_pellet2 <= 1'b1;
							end
						end
					end
				
					if (pellet1_ghost_count == 13'd4 || pellet2_ghost_count == 13'd4) begin
								easter_egg_active <= 1'b1; end
															
					
					if((started && !game_over_active && (freeze_timer == 6'd0))) begin
						ghost_anim_timer <= ghost_anim_timer + 1'b1; end

					if(freeze_timer > 6'd0) begin
						freeze_timer <= freeze_timer - 1'b1; end
					else begin
						if(!eaten_pellet[eat_idx] && !no_pellet) begin
						  eaten_pellet[eat_idx] <= 1'b1;
						  pellets_eaten <= pellets_eaten + 1'b1; end
					
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
					
						if ((pellets_eaten + super_pellets_eaten) >= TOTAL_PELLETS) begin
							  game_won_active <= 1'b1;
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
					
						if (blinky_respawn_timer > 7'd0) blinky_respawn_timer <= blinky_respawn_timer - 1'b1;
						if (pinky_respawn_timer > 7'd0) pinky_respawn_timer <= pinky_respawn_timer - 1'b1;
						if (inky_respawn_timer > 7'd0) inky_respawn_timer <= inky_respawn_timer - 1'b1;
						if (clyde_respawn_timer > 7'd0) clyde_respawn_timer <= clyde_respawn_timer - 1'b1;

						if (!started || game_over_active || game_won_active) begin
							  stagger_timer <= 8'd0;
						end else if (stagger_timer < 8'd120) begin
							  stagger_timer <= stagger_timer + 1'b1;
						end

						if (death_timer > 7'd1) begin
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
							  
							  if(lives == 2'd0) begin
							      game_over_active <= 1'b1; end
									
						end else if (pacman_die_collision && !game_over_active) begin
							  death_timer <= 7'd120;
							  stagger_timer <= 8'd0;
							  if (lives > 2'd0) begin
									  lives <= lives - 1'b1; end 
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
			COLOR:
				 begin
					  the_vga_draw_frame_write_mem_address <= ((pacman_x_pos + draw_x) * VIRTUAL_PIXEL_HEIGHT) + (pacman_y_pos + draw_y);							
					  the_vga_draw_frame_write_mem_data <= final_player_color;
					  the_vga_draw_frame_write_a_pixel <= 1'b1;

					  if(draw_x < PACMAN_SIZE - 1)
							draw_x <= draw_x + 1'b1;
					  else begin
							draw_x <= 10'd0;
							if(draw_y < PACMAN_SIZE - 1)
								 draw_y <= draw_y + 1'b1;
							else
								 draw_y <= 10'd0;
					  end
				 end
			COLOR_GHOST: begin
					 the_vga_draw_frame_write_mem_address <= ((active_ghost_x + draw_x) * VIRTUAL_PIXEL_HEIGHT) + (active_ghost_y + draw_y);
					 the_vga_draw_frame_write_mem_data <= final_ghost_color;
					 the_vga_draw_frame_write_a_pixel <= 1'b1;

					 if (draw_x < PACMAN_SIZE - 1)
						  draw_x <= draw_x + 1'b1;
					 else begin
						  draw_x <= 10'd0;
						  if (draw_y < PACMAN_SIZE - 1)
								draw_y <= draw_y + 1'b1;
						  else begin
								draw_y <= 10'd0;
								if (ghost_select < 2'b11)
								    ghost_select <= ghost_select + 1'b1; //moves between the ghosts
						  end
					 end
				end
			DRAW_LIVES: begin
					the_vga_draw_frame_write_mem_address <= ((lives_x + draw_x) * VIRTUAL_PIXEL_HEIGHT) + (lives_y + draw_y);
					the_vga_draw_frame_write_mem_data    <= ((lives_idx < lives) && player_visible) ? lives_raw_color : 24'h000000;
					the_vga_draw_frame_write_a_pixel     <= 1'b1;

					if (draw_x < 10'd5) begin
						draw_x <= draw_x + 1'b1;
					end else begin
						draw_x <= 10'd0;
						if (draw_y < 10'd7) begin
							draw_y <= draw_y + 1'b1;
						end else begin
							draw_y <= 10'd0;
							if (lives_idx < 2'd2)
								lives_idx <= lives_idx + 1'b1;
							else
								lives_idx <= 2'd0;
						end
					end
				end
			DRAW_WALL: 
				begin
					en_pellet1 <= 1'b0;
					en_pellet2 <= 1'b0;
					the_vga_draw_frame_write_mem_address <= (({11'd0, tile_x_idx} * 16'd8 + {6'd0, draw_x}) * VIRTUAL_PIXEL_HEIGHT) + ({12'd0, tile_y_idx} * 16'd8 + {6'd0, draw_y});				  
					
					if (game_over_color != 24'h000000) begin
						the_vga_draw_frame_write_mem_data <= game_over_color;
					end else if (game_won_color != 24'h000000) begin
						the_vga_draw_frame_write_mem_data <= game_won_color;
					end else begin
						the_vga_draw_frame_write_mem_data <= (is_gate_bar ? 24'hFFB8FF : (is_wall_border ? (easter_egg_active ? 24'h00FF00 :24'h0000FF) : (draw_pellet ? (easter_egg_active ? 25'hEBB434 : 24'hFFB8AE) : (draw_super_pellet ? 24'hFFB8AE : 24'h000000)))); end
					
					the_vga_draw_frame_write_a_pixel <= 1'b1;
						
					if (draw_x < 10'd7) begin
						draw_x <= draw_x + 1'b1;  // sweeps pixels of each tile x0-x7
					end 
					else begin
						draw_x <= 10'd0;
							 
						if (draw_y < 10'd7) begin
							draw_y <= draw_y + 1'b1; // sweeps pixels of each tile y0-y7
				 		end
						else begin
							draw_y <= 10'd0;
									
							if (tile_x_idx < 5'd19) begin
								tile_x_idx <= tile_x_idx + 1'b1; // sweeps tile x across screen 0-19
							end 
							else begin
								tile_x_idx <= 5'd0;
										 
								if (tile_y_idx < 4'd14) begin
									tile_y_idx <= tile_y_idx + 1'b1; // sweeps tile y down the screen 0-14
								end 
								else begin
									tile_y_idx <= 4'd0;
									draw_x <= 10'd0;
									draw_y <= 10'd0;
								end
							end
						end
					end
				end

			SYNC_HIGH:
				begin
					the_vga_draw_frame_write_a_pixel <= 1'b0; //resets cycle repeats
					draw_x <= 10'd0;
					draw_y <= 10'd0;
				end

			GAME_OVER: 
				begin
					the_vga_draw_frame_write_a_pixel <= 1'b0; 
				end
		endcase
	end
end

three_decimal_vals_w_neg my_three_decimal_vals_w_neg(pellets_eaten, super_pellets_eaten, total_ghost_score, HEX3, HEX2, HEX1, HEX0);
endmodule