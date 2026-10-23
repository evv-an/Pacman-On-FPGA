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
//reg [7:0]S;
//reg [7:0]NS;
//parameter 
//	START 			= 8'd0,
//	// W2M is write to memory
//	W2M_INIT 		= 8'd1,
//	W2M_COND 		= 8'd2,
//	W2M_INC 			= 8'd3,
//	W2M_DONE 		= 8'd4,
// The RFM = READ_FROM_MEMORY reading cycles
//	RFM_INIT_START = 8'd5,
//	RFM_INIT_WAIT 	= 8'd6,
//	RFM_DRAWING 	= 8'd7,
//	ERROR 			= 8'hFF;

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

reg[9:0] square_x_pos = 10'd50; //starting x pos (top left corner)
reg[9:0] square_y_pos = 10'd50; //starting y pos (top left corner)
parameter SQUARE_SIZE = 10'd10; //dimensions (10'd20 = 20x20). can't be bigger than the resolution
reg[9:0] draw_x;
reg[9:0] draw_y;
reg [1:0] direction; // key3 L, key2 U, key1 D, key0 R

reg [2:0]S;
reg [2:0]NS;
parameter START = 3'b000,
				CLEAR = 3'b001,
				WAIT = 3'b010,
				SYNC_LOW = 3'b011, //prevents white flashes while moving, waits for the screen to stop scanning before drawing the next frame
				ERASE = 3'b100,
				MOVE = 3'b101,
				COLOR = 3'b110,
				SYNC_HIGH = 3'b111; //waits for screen to start scanning
				
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
						NS = COLOR;
					else
						NS = CLEAR;
				end
			
			WAIT:
				begin
					if (KEY[3:0] != 4'b1111) //if any key is pressed, goes to sync low so the box doesn't glitch
						NS = SYNC_LOW;
					else
						NS = WAIT;
				end
				
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
			MOVE: NS = COLOR;
			COLOR: 
				begin
					if ((draw_x == SQUARE_SIZE - 1) && (draw_y == SQUARE_SIZE - 1)) //once the new location is painted white, move on
						NS = SYNC_HIGH;
					else
						NS = COLOR;
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
			
			square_x_pos <= (VIRTUAL_PIXEL_WIDTH / 2) - (SQUARE_SIZE / 2); //starting position (reads via top left corner of box)
			square_y_pos <= (VIRTUAL_PIXEL_HEIGHT / 2) - (SQUARE_SIZE / 2); // same for y
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
					
					if(KEY[2] == 1'b0)
						direction <= 2'b00; //up
					else if(KEY[1] == 1'b0)
						direction <= 2'b01; //down       // key a being pressed --> moving in direction a, etc.
					else if(KEY[3] == 1'b0)
						direction <= 2'b10; //left
					else if(KEY[0] == 1'b0)
						direction <= 2'b11; //right
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
						
						case(direction)
							2'b00: if(square_y_pos > 0)
										square_y_pos <= (square_y_pos - 1'b1);
							2'b01: if((square_y_pos + SQUARE_SIZE) < (VIRTUAL_PIXEL_HEIGHT - 1'b1)) //determines direction of movement
										square_y_pos <= (square_y_pos + 1'b1);
							2'b10: if(square_x_pos > 0)
										square_x_pos <= (square_x_pos - 1'b1);
							2'b11: if((square_x_pos + SQUARE_SIZE) < (VIRTUAL_PIXEL_WIDTH - 1'b1)) //2'b00 and 2'b10 are longer because they are the
										square_x_pos <= (square_x_pos + 1'b1);                        //sides that DONT directly touch the borders (top left corner)
						endcase
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