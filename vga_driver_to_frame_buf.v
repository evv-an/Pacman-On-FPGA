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
	input [3:0]KEY,         // key 3-0 is awsd directions
	input CLOCK_50,
	input [35:0]GPIO_0,	// gpio for joystick->arduino->breadboard->fpga
	input [9:0]SW,		// sw9 is on/off switch													
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

//define tile for ghost gate and border drawing
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

// pacman sprite drawing
wire[23:0] pacman_color;

pacman_sprite pacman_render(
    .draw_x(draw_x[2:0]),
    .draw_y(draw_y[2:0]),
    .direction(direction),
    .color(pacman_color));
	
	

//pellet system logic & registers 

reg [299:0] eaten_pellet;
reg [12:0] pellets_eaten;

wire[4:0] pacman_center_tile_x = (pacman_x_pos + 10'd4) >> 3; //knows when pacman hits center of tile
wire[3:0] pacman_center_tile_y = (pacman_y_pos + 10'd4) >> 3; 

wire[8:0] eat_idx = (pacman_center_tile_y * 5'd20) + (5'd19 - pacman_center_tile_x); //tracks pacman tile index for eating while moving
wire[8:0] draw_idx = (tile_y_idx * 5'd20) + (5'd19 - tile_x_idx);							 //tracks tile index being scanned by vga renderer


//game logic: locations pellets cannot spawn (ranges of tiles)
wire warp_hallway = (pacman_center_tile_x == 5'd9) && (pacman_center_tile_y <= 4'd1 || pacman_center_tile_y >= 4'd13 || pacman_center_tile_y == 4'd3 || pacman_center_tile_y == 4'd11);
wire ghost_cage = (pacman_center_tile_x >= 5'd6 && pacman_center_tile_x <= 5'd12) && (pacman_center_tile_y >= 4'd4 && pacman_center_tile_y <= 4'd10);
wire spawn_tile = (pacman_center_tile_x == 5'd16) && (pacman_center_tile_y == 4'd7);
wire no_pellet = warp_hallway || ghost_cage || spawn_tile;

//vga logic: locations pellets cannot spawn (ranges of tiles)
wire draw_is_warp_hallway = (tile_x_idx == 5'd9) && (tile_y_idx <= 4'd1 || tile_y_idx >= 4'd13 || tile_y_idx == 4'd3 || tile_y_idx == 4'd11);
wire draw_is_ghost_cage = (tile_x_idx >= 5'd6 && tile_x_idx <= 5'd12) && (tile_y_idx >= 4'd4 && tile_y_idx <= 4'd10);
wire draw_is_spawn_tile = (tile_x_idx == 5'd16) && (tile_y_idx == 4'd7);
wire draw_no_pellet = draw_is_warp_hallway || draw_is_ghost_cage || draw_is_spawn_tile;

wire is_pellet_center = (draw_x >= 10'd3 && draw_x <= 10'd4) && (draw_y >= 10'd3 && draw_y <= 10'd4); //pellet 2x2 dot in center of tile
wire is_pellet_eaten = eaten_pellet[draw_idx]; //checks if pellet is already eaten
wire draw_pellet = !is_draw_wall && !draw_no_pellet && !is_pellet_eaten && is_pellet_center;



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

//ghost specific target calculations [general logic in ghost_controller.v , pinky&clyde&inky logic is slightly modified off of that]
	//pacman position for ghosts to read
wire [4:0] pacman_tile_x = pacman_x_pos >> 3;
wire [3:0] pacman_tile_y = pacman_y_pos >> 3;	

	//blinky
wire [9:0] blinky_x_pos;
wire [9:0] blinky_y_pos;
wire [1:0] blinky_dir;
wire [4:0] blinky_target_x = pacman_center_tile_x;
wire [3:0] blinky_target_y = pacman_center_tile_y;

	//pinky (same as blinky but targets the tile four ahead of direction pacman faces)
wire [9:0] pinky_x_pos;
wire [9:0] pinky_y_pos;
wire [1:0] pinky_dir;
wire [4:0] pinky_target_x = (direction == 2'b11) ? ((pacman_center_tile_x < 5'd15) ? pacman_center_tile_x + 5'd4 : 5'd19) : (direction == 2'b10) ? ((pacman_center_tile_x > 5'd4) ? pacman_center_tile_x - 5'd4 : 5'd0) : pacman_center_tile_x;
wire [3:0] pinky_target_y = (direction == 2'b01) ? ((pacman_center_tile_y < 4'd10) ? pacman_center_tile_y + 4'd4 : 4'd14) : (direction == 2'b00) ? ((pacman_center_tile_y > 4'd4) ? pacman_center_tile_y - 4'd4 : 4'd0) : pacman_center_tile_y;

	//inky
wire [9:0] inky_x_pos;
wire [9:0] inky_y_pos;
wire [1:0] inky_dir;
wire [4:0] blinky_tile_x = blinky_x_pos >> 3;
wire [3:0] blinky_tile_y = blinky_y_pos >> 3;
wire [5:0] pacman_2x_x = pacman_center_tile_x << 1;
wire [4:0] pacman_2x_y = pacman_center_tile_y << 1;
wire [4:0] inky_target_x = (pacman_2x_x < blinky_tile_x) ? 5'd0 : ((pacman_2x_x - blinky_tile_x) > 5'd19) ? 5'd19 : (pacman_2x_x - blinky_tile_x);
wire [3:0] inky_target_y = (pacman_2x_y < blinky_tile_y) ? 4'd0 : ((pacman_2x_y - blinky_tile_y) > 4'd14) ? 4'd14 :(pacman_2x_y - blinky_tile_y);
	
	
	//clyde
wire [9:0] clyde_x_pos;
wire [9:0] clyde_y_pos;
wire [1:0] clyde_dir;
wire [4:0] clyde_tile_x = clyde_x_pos >> 3;
wire [3:0] clyde_tile_y = clyde_y_pos >> 3;
wire [4:0] clyde_dx = (clyde_tile_x > pacman_center_tile_x) ? (clyde_tile_x - pacman_center_tile_x) : (pacman_center_tile_x - clyde_tile_x);
wire [3:0] clyde_dy = (clyde_tile_y > pacman_center_tile_y) ? (clyde_tile_y - pacman_center_tile_y) : (pacman_center_tile_y - clyde_tile_y);
wire [9:0] clyde_dist_sq = (clyde_dx * clyde_dx) + (clyde_dy * clyde_dy);
wire [4:0] clyde_target_x = (clyde_dist_sq > 10'd64) ? pacman_center_tile_x : 5'd0;
wire [3:0] clyde_target_y = (clyde_dist_sq > 10'd64) ? pacman_center_tile_y : 4'd14;

	//ghost logic instantiations (ghost_controller.v)
ghost_controller blinky_ai(
    .clk(clk), .rst(rst), .started(started),
    .release_signal(1'b1),
	 .frame_tick(frame_tick),
    .spawn_x(10'd56), .spawn_y(10'd56),
    .release_x(10'd56), .release_y(10'd56),
    .initial_direction(2'b10),
    .target_tile_x(blinky_target_x), .target_tile_y(blinky_target_y),
    .speed_mask(2'b11),
    .ghost_x_pos(blinky_x_pos), .ghost_y_pos(blinky_y_pos), .ghost_direction(blinky_dir)
);

ghost_controller pinky_ai(
    .clk(clk), .rst(rst), .started(started),
    .release_signal(pellets_eaten >= 13'd5),
    .spawn_x(10'd72), .spawn_y(10'd64),
    .release_x(10'd56), .release_y(10'd56),
    .initial_direction(2'b01),
	 .frame_tick(frame_tick),
    .target_tile_x(pinky_target_x), .target_tile_y(pinky_target_y),
    .speed_mask(2'b11),
    .ghost_x_pos(pinky_x_pos), .ghost_y_pos(pinky_y_pos), .ghost_direction(pinky_dir)
);

ghost_controller inky_ai(
    .clk(clk), .rst(rst), .started(started),
    .release_signal(pellets_eaten >= 13'd30),
    .spawn_x(10'd72), .spawn_y(10'd56),
    .release_x(10'd56), .release_y(10'd56),
    .initial_direction(2'b00),
    .frame_tick(frame_tick),
    .target_tile_x(inky_target_x), .target_tile_y(inky_target_y),
    .speed_mask(2'b11),
    .ghost_x_pos(inky_x_pos), .ghost_y_pos(inky_y_pos), .ghost_direction(inky_dir)
);

ghost_controller clyde_ai(
    .clk(clk), .rst(rst), .started(started),
    .release_signal(pellets_eaten >= 13'd60),
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
    .color(blinky_raw_color)
);

pinky_sprite pinky_render_inst(
    .draw_x(draw_x[2:0]),
    .draw_y(draw_y[2:0]),
    .direction(active_ghost_dir),
    .color(pinky_raw_color)
);

inky_sprite inky_render_inst(
    .draw_x(draw_x[2:0]),
    .draw_y(draw_y[2:0]),
    .direction(active_ghost_dir),
    .color(inky_raw_color)
);

clyde_sprite clyde_render_inst(
    .draw_x(draw_x[2:0]),
    .draw_y(draw_y[2:0]),
    .direction(active_ghost_dir),
    .color(clyde_raw_color)
);
//mux based on ghost_select
reg [23:0] final_ghost_color;

always @(*) begin
    case (ghost_select)
        2'b00: final_ghost_color = blinky_raw_color;
        2'b01: final_ghost_color = pinky_raw_color;
        2'b10: final_ghost_color = inky_raw_color;
        2'b11: final_ghost_color = clyde_raw_color;
        default: final_ghost_color = 24'h000000;
    endcase
end

reg [9:0] draw_x;
reg [9:0] draw_y;

//ghost release conditions
reg pinky_release;


//key latching / movement helpers
reg [1:0] direction; // key3 left, key2 up, key1 down, key0 right
reg started;

//regulating ghost speed
wire frame_tick = (S == MOVE);

//fsm parameters
reg [3:0]S;
reg [3:0]NS;



parameter START = 4'b0000,
			CLEAR = 4'b0001,
			WAIT = 4'b0010,
			SYNC_LOW = 4'b0011, //prevent white flashes while moving, waits for screen to stop scanning until render next frame
			ERASE = 4'b0100,
			MOVE = 4'b0101,
			COLOR = 4'b0110,
			DRAW_WALL = 4'b0111,
			SYNC_HIGH = 4'b1000, //waits for screen to start scanning
			COLOR_GHOST = 4'b1001;
			
//joystick wires
wire joy_up = KEY[2] && GPIO_0[0];
wire joy_down = KEY[1] && GPIO_0[1];
wire joy_left =  KEY[3] && GPIO_0[2];
wire joy_right = KEY[0] && GPIO_0[3];


// key latching logic. makes movement continuous (no need to hold key) & joystick
always @(posedge clk or negedge rst) 
		if (!rst) 
			begin
				direction <= 2'b00;
				started <= 1'b0;
			end
		else
			begin
				if (joy_up == 1'b0) begin //up		
					started <= 1'b1;		            
					if (!wall_above)  		         
						direction <= 2'b00; end
				else if (joy_down == 1'b0) begin //down
					started <= 1'b1;
					if (!wall_below)
						direction <= 2'b01; end
				else if (joy_left == 1'b0) begin //left
					started <= 1'b1;
					if (!wall_left)
						direction <= 2'b10; end
				else if (joy_right == 1'b0) begin //right
					started <= 1'b1;
					if (!wall_right)
						direction <= 2'b11; end
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
		
		COLOR_GHOST: NS = ((draw_x == PACMAN_SIZE - 1) && (draw_y == PACMAN_SIZE - 1) && (ghost_select == 2'b11)) ? SYNC_HIGH : COLOR_GHOST;
			
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
		pellets_eaten <= 13'd0;
		
		ghost_select <= 1'b0;
		
	end

	else
	begin
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
			end
				
			SYNC_LOW:
			begin
				the_vga_draw_frame_write_a_pixel <= 1'b0; 
			end

			ERASE: 
			begin
				the_vga_draw_frame_write_mem_address <= ((pacman_x_pos + draw_x) * VIRTUAL_PIXEL_HEIGHT) + (pacman_y_pos + draw_y); 								the_vga_draw_frame_write_mem_data <= 24'h000000;
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
				draw_x <= 10'd0; // resets values
				draw_y <= 10'd0;
				the_vga_draw_frame_write_a_pixel <= 1'b0;
				tile_x_idx <= 5'd0;
				tile_y_idx <= 4'd0;
				
				if(!eaten_pellet[eat_idx] && !no_pellet) begin
					eaten_pellet[eat_idx] <= 1'b1;
					pellets_eaten <= pellets_eaten + 1'b1; end
									 
				if (started) begin
					case(direction)
						2'b00: if((pacman_y_pos > 0) && !wall_above)
								pacman_y_pos <= (pacman_y_pos - 1'b1);
								
						2'b01: if(((pacman_y_pos + PACMAN_SIZE) < (VIRTUAL_PIXEL_HEIGHT - 1'b1)) && !wall_below) //determines direction of movement
								pacman_y_pos <= (pacman_y_pos + 1'b1);
								
						2'b10: if((pacman_x_pos > 0) && !wall_left)
								pacman_x_pos <= (pacman_x_pos - 1'b1);
								
						2'b11: if(((pacman_x_pos + PACMAN_SIZE) < (VIRTUAL_PIXEL_WIDTH - 1'b1)) && !wall_right) 													
								pacman_x_pos <= (pacman_x_pos + 1'b1);
								
					endcase
						if (pacman_y_pos == 1'b0) begin
								pacman_y_pos <= (VIRTUAL_PIXEL_HEIGHT - PACMAN_SIZE - 2'b10); end
						else if (pacman_y_pos == (VIRTUAL_PIXEL_HEIGHT - PACMAN_SIZE - 1'b1)) begin
								pacman_y_pos <= 1'b1; end
								end
							end
						
			COLOR:
				begin
					the_vga_draw_frame_write_mem_address <= ((pacman_x_pos + draw_x) * VIRTUAL_PIXEL_HEIGHT) + (pacman_y_pos + draw_y); 								
					the_vga_draw_frame_write_mem_data <= pacman_color;
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

			DRAW_WALL: 
				begin
					the_vga_draw_frame_write_mem_address <= (({11'd0, tile_x_idx} * 16'd8 + {6'd0, draw_x}) * VIRTUAL_PIXEL_HEIGHT) + ({12'd0, tile_y_idx} * 16'd8 + {6'd0, draw_y});				  
					the_vga_draw_frame_write_mem_data <= is_gate_bar ? 24'hFFB8FF : (is_wall_border ? 24'h0000FF : (draw_pellet ? 24'hFFB8AE : 24'h000000));
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
		endcase
	end
end

three_decimal_vals_w_neg my_three_decimal_vals_w_neg(pellets_eaten, HEX3, HEX2, HEX1, HEX0);
endmodule