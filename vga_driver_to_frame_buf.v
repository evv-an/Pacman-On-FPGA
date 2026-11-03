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
	input [9:0]SW,		// sw9 is on/off switch													
	output VGA_SYNC_N,														
	output VGA_VS,
	output reg [8:0]pellets_eaten); //counts pellets eaten for score display



assign	HEX0 =	7'h00;
assign	HEX1 =	7'h00;
assign	HEX2 =	7'h00;
assign	HEX3 =	7'h00;

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

// draws a line of blue on wall borders that are touching path
wire is_top_border = (draw_y == 10'd0) && !wall_above_render;
wire is_bottom_border = (draw_y == 10'd7) && !wall_below_render;
wire is_left_border = (draw_x == 10'd0) && !wall_left_render;
wire is_right_border = (draw_x == 10'd7) && !wall_right_render;
wire is_wall_border = is_draw_wall && (is_top_border || is_bottom_border || is_left_border || is_right_border);

wire is_corner = ((draw_x == 10'd0 || draw_x == 10'd7) && (draw_y == 10'd0 || draw_y == 10'd7));

// pacman sprite drawing
wire[23:0] pacman_color;

pacman_sprite pacman_render(
    .draw_x(draw_x[2:0]),
    .draw_y(draw_y[2:0]),
    .direction(direction),
    .color(pacman_color));
	
	
	
	
	
	
reg [9:0] blinky_x_pos;
reg [9:0] blinky_y_pos;
reg [1:0] blinky_dir;
reg [1:0] blinky_speed_counter;

wire[23:0] blinky_color;

blinky_sprite blinky_render(
    .draw_x(draw_x[2:0]),
    .draw_y(draw_y[2:0]),
    .direction(blinky_dir),
    .color(blinky_color));

	

//pellet system logic & registers 

reg[299:0] eaten_pellet;

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

// detects walls for blinky (red)
wire [4:0] b_next_x_left = (blinky_x_pos > 0) ? ((blinky_x_pos - 1'b1) >> 3) : 5'd0;
wire [4:0] b_next_x_right = (blinky_x_pos + PACMAN_SIZE) >> 3;
wire [3:0] b_next_y_top = (blinky_y_pos > 0) ? ((blinky_y_pos - 1'b1) >> 3) : 4'd0;
wire [3:0] b_next_y_bottom = (blinky_y_pos + PACMAN_SIZE) >> 3;

wire [4:0] b_curr_x_left = blinky_x_pos >> 3;
wire [4:0] b_curr_x_right = (blinky_x_pos + PACMAN_SIZE - 1'b1) >> 3;
wire [3:0] b_curr_y_top = blinky_y_pos >> 3;
wire [3:0] b_curr_y_bottom = (blinky_y_pos + PACMAN_SIZE - 1'b1) >> 3;

wire b_w_up_l;
wire b_w_up_r;
wire b_w_dn_l;
wire b_w_dn_r;
wire b_w_lt_t;
wire b_w_lt_b; 
wire b_w_rt_t; 
wire b_w_rt_b;

tilemap_rom b_tile_up_l(
	.tile_x(b_curr_x_left), 
	.tile_y(b_next_y_top),   
	.is_wall(b_w_up_l));
	
tilemap_rom b_tile_up_r(
	.tile_x(b_curr_x_right), 
	.tile_y(b_next_y_top),    
	.is_wall(b_w_up_r));
	
tilemap_rom b_tile_dn_l(
	.tile_x(b_curr_x_left),  
	.tile_y(b_next_y_bottom), 
	.is_wall(b_w_dn_l));
	
tilemap_rom b_tile_dn_r(
	.tile_x(b_curr_x_right),
	.tile_y(b_next_y_bottom), 
	.is_wall(b_w_dn_r));
	
tilemap_rom b_tile_lt_t(
	.tile_x(b_next_x_left),  
	.tile_y(b_curr_y_top),    
	.is_wall(b_w_lt_t));
	
tilemap_rom b_tile_lt_b(
	.tile_x(b_next_x_left),  
	.tile_y(b_curr_y_bottom), 
	.is_wall(b_w_lt_b));
	
tilemap_rom b_tile_rt_t(
	.tile_x(b_next_x_right), 
	.tile_y(b_curr_y_top),    
	.is_wall(b_w_rt_t));
	
tilemap_rom b_tile_rt_b(
	.tile_x(b_next_x_right), 
	.tile_y(b_curr_y_bottom),
	.is_wall(b_w_rt_b));

wire blinky_wall_above = b_w_up_l | b_w_up_r;
wire blinky_wall_below = b_w_dn_l | b_w_dn_r;
wire blinky_wall_left  = b_w_lt_t | b_w_lt_b;
wire blinky_wall_right = b_w_rt_t | b_w_rt_b;


// detects when blinky hits center of tile
wire [4:0] blinky_tile_x = blinky_x_pos >> 3;
wire [3:0] blinky_tile_y = blinky_y_pos >> 3;
wire is_blinky_tile_center = (blinky_x_pos[2:0] == 3'd0) && (blinky_y_pos[2:0] == 3'd0); //calculates blinky center

// blinky pathing algorithm - calculates distance from pacman for each direction
wire [4:0] x_up = (blinky_tile_x > pacman_center_tile_x) ? (blinky_tile_x - pacman_center_tile_x) : (pacman_center_tile_x - blinky_tile_x);
wire [4:0] x_down = x_up;
wire [4:0] x_left = ((blinky_tile_x - 1'b1) > pacman_center_tile_x) ? ((blinky_tile_x - 1'b1) - pacman_center_tile_x) : (pacman_center_tile_x - (blinky_tile_x - 1'b1));
wire [4:0] x_right = ((blinky_tile_x + 1'b1) > pacman_center_tile_x) ? ((blinky_tile_x + 1'b1) - pacman_center_tile_x) : (pacman_center_tile_x - (blinky_tile_x + 1'b1));

wire [3:0] y_up = ((blinky_tile_y - 1'b1) > pacman_center_tile_y) ? ((blinky_tile_y - 1'b1) - pacman_center_tile_y) : (pacman_center_tile_y - (blinky_tile_y - 1'b1));
wire [3:0] y_down = ((blinky_tile_y + 1'b1) > pacman_center_tile_y) ? ((blinky_tile_y + 1'b1) - pacman_center_tile_y) : (pacman_center_tile_y - (blinky_tile_y + 1'b1));
wire [3:0] y_left = (blinky_tile_y > pacman_center_tile_y) ? (blinky_tile_y - pacman_center_tile_y) : (pacman_center_tile_y - blinky_tile_y);
wire [3:0] y_right = y_left;

wire [9:0] dist_up = (blinky_wall_above || blinky_dir == 2'b01 || blinky_tile_y == 4'd0)  ? 10'h3FF : (x_up * x_up + y_up * y_up);
wire [9:0] dist_down = (blinky_wall_below || blinky_dir == 2'b00 || blinky_tile_y == 4'd14) ? 10'h3FF : (x_down * x_down + y_down * y_down);
wire [9:0] dist_left = (blinky_wall_left  || blinky_dir == 2'b11 || blinky_tile_x == 5'd0)  ? 10'h3FF : (x_left * x_left + y_left * y_left);
wire [9:0] dist_right = (blinky_wall_right || blinky_dir == 2'b10 || blinky_tile_x == 5'd19) ? 10'h3FF : (x_right * x_right + y_right * y_right);

// direction hierarchy (up, left, down, right)
wire [1:0] best_blinky_dir = (dist_up <= dist_left && dist_up <= dist_down && dist_up <= dist_right) ? 2'b00 :
                             (dist_left <= dist_down && dist_left <= dist_right) ? 2'b10 :
                             (dist_down <= dist_right) ? 2'b01 : 2'b11;

wire [1:0] next_blinky_dir = is_blinky_tile_center ? best_blinky_dir : blinky_dir;

reg [4:0] tile_x_idx; // 0 to 19 (8x8 pixel tiles)
reg [3:0] tile_y_idx; // 0 to 14
wire is_draw_wall;

tilemap_rom map_render(
    .tile_x(tile_x_idx),
    .tile_y(tile_y_idx),
    .is_wall(is_draw_wall));

// detects walls around tiles				
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


reg[9:0] pacman_x_pos;
reg[9:0] pacman_y_pos;
parameter PACMAN_SIZE = 10'd8; //dimensions of pacman (also tile length and width)

reg[9:0] draw_x;
reg[9:0] draw_y;

reg [1:0] direction; // key3 left, key2 up, key1 down, key0 right
reg started;

// fsm state parameters
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

// key latching logic. makes movement continuous (no need to hold key)
always @(posedge clk or negedge rst) 
		if (!rst) 
			begin
				direction <= 2'b00;	// key latching logic. makes movement continuous so no need to hold a key
				started <= 1'b0;
			end
		else
			begin
				if (KEY[2] == 1'b0) begin //up		//nested if statements to protect movement from stopping
					started <= 1'b1;		            //if pressed keys direction is not a playable tile
					if (!wall_above)  		         
						direction <= 2'b00; end
				else if (KEY[1] == 1'b0) begin //down
					started <= 1'b1;
					if (!wall_below)
						direction <= 2'b01; end
				else if (KEY[3] == 1'b0) begin //left
					started <= 1'b1;
					if (!wall_left)
						direction <= 2'b10; end
				else if (KEY[0] == 1'b0) begin //right
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
			if ((draw_x == PACMAN_SIZE - 1) && (draw_y == PACMAN_SIZE -1)) //once the old location is painted black, move on
				NS = MOVE;
			else
				NS = ERASE;
		end

		MOVE: NS = DRAW_WALL;

		COLOR: 
		begin	
			if ((draw_x == PACMAN_SIZE - 1) && (draw_y == PACMAN_SIZE - 1)) //once the new location is painted, move on
				NS = COLOR_GHOST;
			else
				NS = COLOR;
		end
		
		COLOR_GHOST:
		begin
			if ((draw_x == PACMAN_SIZE - 1) && (draw_y == PACMAN_SIZE - 1)) // draws blinky
				NS = SYNC_HIGH;
			else
				NS = COLOR_GHOST;
		end
			
		DRAW_WALL:
		begin 
			if ((draw_x == 10'd7) && (draw_y == 10'd7) && (tile_x_idx == 5'd19) && (tile_y_idx == 4'd14)) // stops drawing after all pixels have been drawn
				NS = COLOR;
			else
				NS = DRAW_WALL;
		end

		SYNC_HIGH:
		begin
			if (VGA_VS == 1'b1) // waits for vertical sync
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
		the_vga_draw_frame_write_mem_address <= 15'd0; //screen to black
		the_vga_draw_frame_write_mem_data <= 24'd0;
		the_vga_draw_frame_write_a_pixel <= 1'b0;
	
		draw_x <= 10'd0; //resets values
		draw_y <= 10'd0;
		idx_location <= 15'd0;
			
		pacman_x_pos <= 10'd128;
		pacman_y_pos <= 10'd56; 
		
		blinky_x_pos <= 10'd56;
		blinky_y_pos <= 10'd56;
		blinky_dir <= 2'b10;
		blinky_speed_counter <= 2'b00;
			
		tile_x_idx <= 5'd0;
		tile_y_idx <= 4'd0;
		
		eaten_pellet <= 300'd0;
		pellets_eaten <= 9'd0;
		
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
			end
				
			SYNC_LOW:
			begin
				the_vga_draw_frame_write_a_pixel <= 1'b0; 
			end

			ERASE: 
			begin
				the_vga_draw_frame_write_mem_address <= ((pacman_x_pos + draw_x) * VIRTUAL_PIXEL_HEIGHT) + (pacman_y_pos + draw_y); // draws black when player leaves the tile
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
								
						2'b11: if(((pacman_x_pos + PACMAN_SIZE) < (VIRTUAL_PIXEL_WIDTH - 1'b1)) && !wall_right) //2'b00 and 2'b10 are longer because they are the sides that DONT directly touch the borders (top left corner)
								pacman_x_pos <= (pacman_x_pos + 1'b1);
								
					endcase
						if (pacman_y_pos == 1'b0) begin
								pacman_y_pos <= (VIRTUAL_PIXEL_HEIGHT - PACMAN_SIZE - 2'b10); end
						else if (pacman_y_pos == (VIRTUAL_PIXEL_HEIGHT - PACMAN_SIZE - 1'b1)) begin
								pacman_y_pos <= 1'b1; end
						
						
						blinky_speed_counter <= blinky_speed_counter + 1'b1;
						
						if(blinky_speed_counter != 2'b11) begin // blinky moves at 75% speed (100% makes the game impossible)
							blinky_dir <= next_blinky_dir;

							case(next_blinky_dir)
								2'b00: if (!blinky_wall_above) blinky_y_pos <= blinky_y_pos - 1'b1;
								2'b01: if (!blinky_wall_below) blinky_y_pos <= blinky_y_pos + 1'b1;
								2'b10: if (!blinky_wall_left)  blinky_x_pos <= blinky_x_pos - 1'b1;
								2'b11: if (!blinky_wall_right) blinky_x_pos <= blinky_x_pos + 1'b1;
							endcase
							
						if (blinky_y_pos == 1'b0) begin
								blinky_y_pos <= (VIRTUAL_PIXEL_HEIGHT - PACMAN_SIZE - 2'b10); end
						else if (blinky_y_pos == (VIRTUAL_PIXEL_HEIGHT - PACMAN_SIZE - 1'b1)) begin
								blinky_y_pos <= 1'b1; end
							
								end
							end
						end
			COLOR:
				begin
					the_vga_draw_frame_write_mem_address <= ((pacman_x_pos + draw_x) * VIRTUAL_PIXEL_HEIGHT) + (pacman_y_pos + draw_y); // loops to draw pacman pixels white
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
				
			COLOR_GHOST:
				begin
					 the_vga_draw_frame_write_mem_address <= ((blinky_x_pos + draw_x) * VIRTUAL_PIXEL_HEIGHT) + (blinky_y_pos + draw_y);
					 the_vga_draw_frame_write_mem_data <= blinky_color;
					 the_vga_draw_frame_write_a_pixel <= 1'b1;

					 if (draw_x < PACMAN_SIZE - 1)
						  draw_x <= draw_x + 1'b1;
					 else begin
						  draw_x <= 10'd0;
						  if (draw_y < PACMAN_SIZE - 1)
								draw_y <= draw_y + 1'b1;
						  else
								draw_y <= 10'd0;
					 end
				end

			DRAW_WALL: 
				begin
					the_vga_draw_frame_write_mem_address <= (({11'd0, tile_x_idx} * 16'd8 + {6'd0, draw_x}) * VIRTUAL_PIXEL_HEIGHT) + ({12'd0, tile_y_idx} * 16'd8 + {6'd0, draw_y});				  
					the_vga_draw_frame_write_mem_data <= is_wall_border ? 24'h0000FF : (draw_pellet ? 24'hFFB8AE : 24'h000000);
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
endmodule