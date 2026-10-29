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
	output VGA_VS);


// turns off all displays
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
wire [4:0] next_tile_x_left   = (square_x_pos > 0) ? ((square_x_pos - 1'b1) >> 3) : 5'd0;
wire [4:0] next_tile_x_right  = (square_x_pos + SQUARE_SIZE) >> 3;
wire [3:0] next_tile_y_top    = (square_y_pos > 0) ? ((square_y_pos - 1'b1) >> 3) : 4'd0;
wire [3:0] next_tile_y_bottom = (square_y_pos + SQUARE_SIZE) >> 3;

wire [4:0] curr_tile_x_left   = square_x_pos >> 3;
wire [4:0] curr_tile_x_right  = (square_x_pos + SQUARE_SIZE - 1'b1) >> 3;
wire [3:0] curr_tile_y_top    = square_y_pos >> 3;
wire [3:0] curr_tile_y_bottom = (square_y_pos + SQUARE_SIZE - 1'b1) >> 3;

// draws a line of blue on wall borders that are touching path
wire is_top_border    = (draw_y == 10'd0) && !wall_above_render;
wire is_bottom_border = (draw_y == 10'd7) && !wall_below_render;
wire is_left_border   = (draw_x == 10'd0) && !wall_left_render;
wire is_right_border  = (draw_x == 10'd7) && !wall_right_render;
wire is_wall_border = is_draw_wall && (is_top_border || is_bottom_border || is_left_border || is_right_border);
					
wire is_corner = ((draw_x == 10'd0 || draw_x == 10'd7) && (draw_y == 10'd0 || draw_y == 10'd7));

// pacman sprite drawing
wire is_pacman_pixel;
reg [5:0] pacman_addr;
wire[23:0] pacman_color;

pacmansprite pacman_sprite(
    .address(pacman_addr),
    .clock(clk),
	 .data(24'd0),
	 .wren(1'b0),
    .q(pacman_color));

always @(*) begin
    case (direction)
        2'b11: pacman_addr = {draw_y[2:0], draw_x[2:0] - 3'd1};          //right 
        2'b10: pacman_addr = {draw_y[2:0], 3'd7 - (draw_x[2:0] - 3'd1)};     //left
        2'b00: pacman_addr = {3'd7 - (draw_x[2:0] - 3'd1), draw_y[2:0]};    //up
        2'b01: pacman_addr = {draw_x[2:0] - 3'd1, draw_y[2:0]};           //down
        default: pacman_addr = {draw_y[2:0], 3'd7 - (draw_x[2:0] - 3'd1)};  //defaulted to left
    endcase
end

	
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


reg[9:0] square_x_pos;
reg[9:0] square_y_pos;
parameter SQUARE_SIZE = 10'd8; //dimensions of pacman (also tile length and width)

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
			SYNC_HIGH = 4'b1000; //waits for screen to start scanning


// key latching logic. makes movement continuous (no need to hold key)
always @(posedge clk or negedge rst) 
		if (!rst) 
			begin
				direction <= 2'b11;	// key latching logic. makes movement continuous so no need to hold a key
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
			if ((draw_x == SQUARE_SIZE - 1) && (draw_y == SQUARE_SIZE -1)) //once the old location is painted black, move on
				NS = MOVE;
			else
				NS = ERASE;
		end

		MOVE: NS = DRAW_WALL;

		COLOR: 
		begin	
			if ((draw_x == SQUARE_SIZE - 1) && (draw_y == SQUARE_SIZE - 1)) //once the new location is painted, move on
				NS = SYNC_HIGH;
			else
				NS = COLOR;
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
			
		square_x_pos <= 10'd136;
		square_y_pos <= 10'd56; 
			
		tile_x_idx <= 5'd0;
		tile_y_idx <= 4'd0;
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
				the_vga_draw_frame_write_mem_address <= ((square_x_pos + draw_x) * VIRTUAL_PIXEL_HEIGHT) + (square_y_pos + draw_y); // draws black when player leaves the tile
				the_vga_draw_frame_write_mem_data <= 24'h000000;
				the_vga_draw_frame_write_a_pixel <= 1'b1;
					
				if(draw_x < SQUARE_SIZE - 1)
					draw_x <= draw_x + 1'b1; //loop to draw old box location
				else
				begin
					draw_x <= 10'd0;
						
				if(draw_y < SQUARE_SIZE - 1)
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
									 
				if (started) begin
					case(direction)
						2'b00: if((square_y_pos > 0) && !wall_above)
								square_y_pos <= (square_y_pos - 1'b1);
								
						2'b01: if(((square_y_pos + SQUARE_SIZE) < (VIRTUAL_PIXEL_HEIGHT - 1'b1)) && !wall_below) //determines direction of movement
								square_y_pos <= (square_y_pos + 1'b1);
								
						2'b10: if((square_x_pos > 0) && !wall_left)
								square_x_pos <= (square_x_pos - 1'b1);
								
						2'b11: if(((square_x_pos + SQUARE_SIZE) < (VIRTUAL_PIXEL_WIDTH - 1'b1)) && !wall_right) //2'b00 and 2'b10 are longer because they are the sides that DONT directly touch the borders (top left corner)
								square_x_pos <= (square_x_pos + 1'b1);
								
					endcase
						if (square_y_pos == 1'b0) begin
							square_y_pos <= (VIRTUAL_PIXEL_HEIGHT - SQUARE_SIZE - 2'b10); end
						else if (square_y_pos == (VIRTUAL_PIXEL_HEIGHT - SQUARE_SIZE - 1'b1)) begin
							square_y_pos <= 1'b1; end
							
						end
					end

			COLOR:
				begin
					the_vga_draw_frame_write_mem_address <= ((square_x_pos + draw_x) * VIRTUAL_PIXEL_HEIGHT) + (square_y_pos + draw_y); // loops to draw pacman pixels white
					the_vga_draw_frame_write_mem_data <= pacman_color;
					the_vga_draw_frame_write_a_pixel <= 1'b1;

					if(draw_x < SQUARE_SIZE - 1)
						draw_x <= draw_x + 1'b1;
					else begin
						draw_x <= 10'd0;
						if(draw_y < SQUARE_SIZE - 1)
							draw_y <= draw_y + 1'b1;
					end
				end

			DRAW_WALL: 
				begin
					the_vga_draw_frame_write_mem_address <= (({11'd0, tile_x_idx} * 16'd8 + {6'd0, draw_x}) * VIRTUAL_PIXEL_HEIGHT) + ({12'd0, tile_y_idx} * 16'd8 + {6'd0, draw_y});				  
					the_vga_draw_frame_write_mem_data <= is_wall_border ? 24'h0000FF : 24'h000000;  //pulls address and draws respective color to tile
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