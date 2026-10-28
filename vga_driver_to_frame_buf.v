module vga_driver_to_frame_buf	(
  
	output		     [6:0]		HEX0,
	output		     [6:0]		HEX1,
	output		     [6:0]		HEX2,
	output		     [6:0]		HEX3,
	
	input 		     [3:0]		KEY,
	input CLOCK_50,
	output		     [9:0]		LEDR,
	input 		     [9:0]		SW,
	output		          		VGA_BLANK_N,
	output		     [7:0]		VGA_B,
	output		          		VGA_CLK,
	output		     [7:0]		VGA_G,
	output		          		VGA_HS,                                         //to operate: sw9 is the on/off switch
	output		     [7:0]		VGA_R,														//				: key3-0 are awsd directions
	output		          		VGA_SYNC_N,													// direction hierarchy: up > down > left > right
	output		          		VGA_VS

	

);

// Turn off all displays.
assign	HEX0		=	7'h00;
assign	HEX1		=	7'h00;
assign	HEX2		=	7'h00;
assign	HEX3		=	7'h00;

// DONE STANDARD PORT DECLARATION ABOVE
/* HANDLE SIGNALS FOR CIRCUIT */
wire clk;
wire rst;

assign clk = CLOCK_50;
assign rst = SW[9];

wire [9:0]SW_db;

debounce_switches db(
.clk(clk),
.rst(rst),
.SW(SW), 
.SW_db(SW_db)
);

// VGA DRIVER
wire active_pixels; // is on when we're in the active draw space
wire frame_done;
wire [9:0]x; // current x
wire [9:0]y; // current y - 10 bits = 1024 ... a little bit more than we need

/* the 3 signals to set to write to the picture */
reg [14:0] the_vga_draw_frame_write_mem_address;
reg [23:0] the_vga_draw_frame_write_mem_data;
reg the_vga_draw_frame_write_a_pixel;

/* This is the frame driver point that you can write to the draw_frame */
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

	/* writes to the frame buf - you need to figure out how x and y or other details provide a translation */
	.the_vga_draw_frame_write_mem_address(the_vga_draw_frame_write_mem_address),
	.the_vga_draw_frame_write_mem_data(the_vga_draw_frame_write_mem_data),
	.the_vga_draw_frame_write_a_pixel(the_vga_draw_frame_write_a_pixel)
);

reg [15:0]i;

parameter MEMORY_SIZE = 16'd19200; // 160*120 // Number of memory spots ... highly reduced since memory is slow
parameter PIXEL_VIRTUAL_SIZE = 16'd4; // Pixels per spot - therefore 4x4 pixels are drawn per memory location

/* ACTUAL VGA RESOLUTION */
parameter VGA_WIDTH = 16'd640; 
parameter VGA_HEIGHT = 16'd480;

/* Our reduced RESOLUTION 160 by 120 needs a memory of 19,200 words each 24 bits wide */
parameter VIRTUAL_PIXEL_WIDTH = VGA_WIDTH/PIXEL_VIRTUAL_SIZE; // 160
parameter VIRTUAL_PIXEL_HEIGHT = VGA_HEIGHT/PIXEL_VIRTUAL_SIZE; // 120

/* idx_location stores all the locations in the */
reg [14:0] idx_location;
/* !!!!!!!!!NOTE!!!!!!!
 - FLAG logic is a bad way to approach this, but I was lazy - I should implement this as an FSM for the button grabs.  */
reg flag1;
reg flag2;

// Just so I can see the address being calculated
assign LEDR = idx_location;

wire [4:0] next_tile_x_left   = (square_x_pos > 0) ? ((square_x_pos - 1'b1) >> 3) : 5'd0;
wire [4:0] next_tile_x_right  = (square_x_pos + SQUARE_SIZE) >> 3;
wire [3:0] next_tile_y_top    = (square_y_pos > 0) ? ((square_y_pos - 1'b1) >> 3) : 4'd0;
wire [3:0] next_tile_y_bottom = (square_y_pos + SQUARE_SIZE) >> 3;

wire [4:0] curr_tile_x_left   = square_x_pos >> 3;
wire [4:0] curr_tile_x_right  = (square_x_pos + SQUARE_SIZE - 1'b1) >> 3;
wire [3:0] curr_tile_y_top    = square_y_pos >> 3;
wire [3:0] curr_tile_y_bottom = (square_y_pos + SQUARE_SIZE - 1'b1) >> 3;



wire wall_above, wall_below, wall_left, wall_right;

wire w_up_l, w_up_r;
tilemap_rom tile_up_l (.tile_x(curr_tile_x_left),  .tile_y(next_tile_y_top), .is_wall(w_up_l));
tilemap_rom tile_up_r (.tile_x(curr_tile_x_right), .tile_y(next_tile_y_top), .is_wall(w_up_r));
assign wall_above = w_up_l | w_up_r;

wire w_dn_l, w_dn_r;
tilemap_rom tile_dn_l (.tile_x(curr_tile_x_left),  .tile_y(next_tile_y_bottom), .is_wall(w_dn_l));
tilemap_rom tile_dn_r (.tile_x(curr_tile_x_right), .tile_y(next_tile_y_bottom), .is_wall(w_dn_r)); //instantiating tile readings from
assign wall_below = w_dn_l | w_dn_r;

wire w_lt_t, w_lt_b;
tilemap_rom tile_lt_t (.tile_x(next_tile_x_left), .tile_y(curr_tile_y_top),    .is_wall(w_lt_t)); // tilemap_rom.v for current & next tile data
tilemap_rom tile_lt_b (.tile_x(next_tile_x_left), .tile_y(curr_tile_y_bottom), .is_wall(w_lt_b));
assign wall_left = w_lt_t | w_lt_b;

wire w_rt_t, w_rt_b;
tilemap_rom tile_rt_t (.tile_x(next_tile_x_right), .tile_y(curr_tile_y_top),    .is_wall(w_rt_t));
tilemap_rom tile_rt_b (.tile_x(next_tile_x_right), .tile_y(curr_tile_y_bottom), .is_wall(w_rt_b));
assign wall_right = w_rt_t | w_rt_b;



reg [4:0] tile_x_idx; // 0 to 19
reg [3:0] tile_y_idx; // 0 to 14
wire is_draw_wall;

tilemap_rom map_render (
    .tile_x(tile_x_idx),
    .tile_y(tile_y_idx),
    .is_wall(is_draw_wall)
);

reg[9:0] square_x_pos;
reg[9:0] square_y_pos;
parameter SQUARE_SIZE = 10'd8; //dimensions (10'd20 = 20x20). can't be bigger than the resolution

reg[9:0] draw_x;
reg[9:0] draw_y;

reg [1:0] direction; // key3 L, key2 U, key1 D, key0 R
reg started;

//reg[3:0] move_divider;

reg [3:0]S;
reg [3:0]NS;

parameter START = 4'b0000,
				CLEAR = 4'b0001,
				WAIT = 4'b0010,
				SYNC_LOW = 4'b0011, //prevents white flashes while moving, waits for the screen to stop scanning before drawing the next frame
				ERASE = 4'b0100,
				MOVE = 4'b0101,
				COLOR = 4'b0110,
				DRAW_WALL = 4'b0111,
				SYNC_HIGH = 4'b1000; //waits for screen to start scanning

always @(posedge clk or negedge rst) 
		if (!rst) 
			begin
				direction <= 2'b11;			// key latching logic. Makes movement continuous so no need to hold a key
				started <= 1'b0;
			end
		else
			begin
				if (KEY[2] == 1'b0) begin //up								//nested if statements to protect movement from stopping
					started <= 1'b1;												//if pressed keys direction is not a playable tile
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
					if(idx_location == 15'd19199) // # of pixels on screen [19199:0]
						NS = DRAW_WALL;
					else
						NS = CLEAR;
				end
			
			WAIT:	NS = SYNC_LOW;
			
			SYNC_LOW: 
				begin
					if(VGA_VS == 1'b0) //waits for vertical sync
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
					if ((draw_x == SQUARE_SIZE - 1) && (draw_y == SQUARE_SIZE - 1)) //once the new location is painted white, move on
						NS = SYNC_HIGH;
					else
						NS = COLOR;
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
					if (VGA_VS == 1'b1) //waits for vertical sync
						NS = WAIT;
					else
						NS = SYNC_HIGH;
				end
			default: NS = START;
		endcase
	end	

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
			
			//move_divider <= 4'd0;
			
	
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
							the_vga_draw_frame_write_mem_address <= idx_location; //clears the whole screen
                     the_vga_draw_frame_write_mem_data <= 24'h000000; //clearing means filling the screen with black
                     the_vga_draw_frame_write_a_pixel <= 1'b1; //writes the black pixel
                     idx_location <= idx_location + 1'b1; //moves
                end
				WAIT:
					begin
						the_vga_draw_frame_write_a_pixel <= 1'b0; //resets while waiting so stages don't overlap
						draw_x <= 10'd0;
						draw_y <= 10'd0;
					end
				SYNC_LOW:
					begin
						the_vga_draw_frame_write_a_pixel <= 1'b0; 
					end
				ERASE: 
					begin
						the_vga_draw_frame_write_mem_address <= ((square_x_pos + draw_x) * VIRTUAL_PIXEL_HEIGHT) + (square_y_pos + draw_y); // address of the box's old position
						the_vga_draw_frame_write_mem_data <= 24'h000000; // colors the old position black
						the_vga_draw_frame_write_a_pixel <= 1'b1; // writes the pixel
					
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
						draw_x <= 10'd0;
						draw_y <= 10'd0;
						the_vga_draw_frame_write_a_pixel <= 1'b0; //resets values
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
								2'b11: if(((square_x_pos + SQUARE_SIZE) < (VIRTUAL_PIXEL_WIDTH - 1'b1)) && !wall_right) //2'b00 and 2'b10 are longer because they are the
											square_x_pos <= (square_x_pos + 1'b1);                       					    //sides that DONT directly touch the borders (top left corner)
							endcase
						if (square_y_pos == 1'b0) begin
							square_y_pos <= (VIRTUAL_PIXEL_HEIGHT - SQUARE_SIZE - 2'b10); end
						else if (square_y_pos == (VIRTUAL_PIXEL_HEIGHT - SQUARE_SIZE - 1'b1)) begin
							square_y_pos <= 1'b1; end
							
						end
					end
				COLOR: 
					begin
						the_vga_draw_frame_write_mem_address <= ((square_x_pos + draw_x) * VIRTUAL_PIXEL_HEIGHT) + (square_y_pos + draw_y); // address of the box's new position
						the_vga_draw_frame_write_mem_data <= 24'hFFFFFF; // colors the new position white
						the_vga_draw_frame_write_a_pixel <= 1'b1; // writes the pixel
					if(draw_x < SQUARE_SIZE - 1)
						draw_x <= draw_x + 1'b1; // loop to draw box
					else
						begin
							draw_x <= 10'd0;
							if(draw_y < SQUARE_SIZE - 1)
								draw_y <= draw_y + 1'b1;
						end
					end
				DRAW_WALL: 
					begin
						 the_vga_draw_frame_write_mem_address <= (({11'd0, tile_x_idx} * 16'd8 + {6'd0, draw_x}) * VIRTUAL_PIXEL_HEIGHT) + ({12'd0, tile_y_idx} * 16'd8 + {6'd0, draw_y});				  
						 the_vga_draw_frame_write_mem_data <= is_draw_wall ? 24'h0000FF : 24'h000000;  //pulls address and draws respective color to tile
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