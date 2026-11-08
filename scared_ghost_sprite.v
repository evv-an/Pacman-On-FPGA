module scared_ghost_sprite(
    input [2:0] draw_x,
    input [2:0] draw_y,
    input flash,        //flash near timer run out
    output reg [23:0] color
);

    // accounts for rotated map
    wire [2:0] px = 3'd7 - draw_y;
    wire [2:0] py = draw_x;

	// flashes red and white
    wire [23:0] body_color = flash ? 24'hFFFFFF : 24'h0000FF;
    wire [23:0] face_color = flash ? 24'hFF0000 : 24'hFFFFFF;

   
    wire is_eye = (py == 3'd2) && (px == 3'd2 || px == 3'd5);
    wire is_mouth = ((py == 3'd4) && (px == 3'd2 || px == 3'd5)) || ((py == 3'd5) && (px == 3'd1 || px == 3'd3 || px == 3'd4 || px == 3'd6));
    wire is_body = (py == 3'd0 && (px >= 3'd2 && px <= 3'd5)) || (py == 3'd1 && (px >= 3'd1 && px <= 3'd6)) || (py >= 3'd2 && py <= 3'd6) || (py == 3'd7 && (px != 3'd2 && px != 3'd5));

    always @(*) begin
        if (is_eye || is_mouth) begin
            color = face_color;
        end else if (is_body) begin
            color = body_color;
        end else begin
            color = 24'h000000;
        end
    end

endmodule