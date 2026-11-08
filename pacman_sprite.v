module pacman_sprite (
    input [2:0] draw_x,
    input [2:0] draw_y,
    input [1:0] direction,   // 00 up, 01 down, 10 left, 11 right
    input [1:0] anim_frame,  // 00 closed, 01/11 half open, 10 wide open
    output reg [23:0] color
);

    // rotates coordinates so one right facing drawing works for every direction
    reg [2:0] px, py;
    always @(*) begin
        case (direction)
            2'b00: begin // up
                px = 3'd7 - draw_y;
                py = draw_x;
            end
            2'b01: begin // down
                px = draw_y;
                py = draw_x;
            end
            2'b10: begin // left
                px = 3'd7 - draw_x;
                py = draw_y;
            end
            2'b11: begin // right
                px = draw_x;
                py = draw_y;
            end
        endcase
    end

    // frame 0: mouth closed (full circle)
    reg [7:0] closed_row;
    always @(*) begin
        case (draw_y)
            3'd0: closed_row = 8'b00111100;
            3'd1: closed_row = 8'b01111110;
            3'd2: closed_row = 8'b11111111;
            3'd3: closed_row = 8'b11111111;
            3'd4: closed_row = 8'b11111111;
            3'd5: closed_row = 8'b11111111;
            3'd6: closed_row = 8'b01111110;
            3'd7: closed_row = 8'b00111100;
        endcase
    end

    // frame 1: mouth half open (cuts 3 pixels in)
    reg [7:0] half_row;
    always @(*) begin
        case (py)
            3'd0: half_row = 8'b00111100;
            3'd1: half_row = 8'b01111110;
            3'd2: half_row = 8'b11111100;
            3'd3: half_row = 8'b11111000; // cuts 3 pixels in
            3'd4: half_row = 8'b11111000;
            3'd5: half_row = 8'b11111100;
            3'd6: half_row = 8'b01111110;
            3'd7: half_row = 8'b00111100;
        endcase
    end

    // frame 2: mouth wide open (cuts 5-6 pixels in, past the center)
    reg [7:0] wide_row;
    always @(*) begin
        case (py)
            3'd0: wide_row = 8'b00111100;
            3'd1: wide_row = 8'b01111100; // cuts 2 pixels in
            3'd2: wide_row = 8'b11110000; // cuts 4 pixels in
            3'd3: wide_row = 8'b11000000; // deepest point, cuts 6 pixels in
            3'd4: wide_row = 8'b11100000; // cuts 5 pixels in
            3'd5: wide_row = 8'b11110000; // cuts 4 pixels in
            3'd6: wide_row = 8'b01111100;
            3'd7: wide_row = 8'b00111100;
        endcase
    end

    // picks the pixel for the current frame
    wire closed_pixel = closed_row[3'd7 - draw_x];
    wire half_pixel   = half_row[3'd7 - px];
    wire wide_pixel   = wide_row[3'd7 - px];

    reg active_pixel;
    always @(*) begin
        case (anim_frame)
            2'b00:        active_pixel = closed_pixel;
            2'b01, 2'b11: active_pixel = half_pixel;   // half open
            2'b10:        active_pixel = wide_pixel;   // wide open
        endcase
    end

    always @(*) begin
        if (active_pixel)
            color = 24'hFFFF00; // pacman yellow
        else
            color = 24'h000000; // black background
    end

endmodule