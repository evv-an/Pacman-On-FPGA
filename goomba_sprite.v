module goomba_sprite(
    input [2:0] draw_x,
    input [2:0] draw_y,
    input [1:0] anim_frame,
    input is_scared,
    output reg [23:0] color
);
parameter BROWN       = 24'h8B3A10;
parameter TAN         = 24'hF8C490;
parameter SCARED_BLUE = 24'h0000FF;
parameter WHITE       = 24'hFFFFFF;
parameter BLACK       = 24'h000000;

// rotates 90 degrees ccw
wire [2:0] py = draw_x;
wire [2:0] px = 3'd7 - draw_y;

always @(*) begin
    if (is_scared) begin
        case ({py, px})
            {3'd0, 3'd2}, {3'd0, 3'd3}, {3'd0, 3'd4}, {3'd0, 3'd5}: color = SCARED_BLUE;
            {3'd1, 3'd1}, {3'd1, 3'd2}, {3'd1, 3'd3}, {3'd1, 3'd4}, {3'd1, 3'd5}, {3'd1, 3'd6}: color = SCARED_BLUE;
            {3'd2, 3'd1}, {3'd2, 3'd2}, {3'd2, 3'd4}, {3'd2, 3'd6}: color = SCARED_BLUE;
            {3'd2, 3'd3}, {3'd2, 3'd5}: color = WHITE;
            {3'd3, 3'd0}, {3'd3, 3'd1}, {3'd3, 3'd3}, {3'd3, 3'd4}, {3'd3, 3'd5}, {3'd3, 3'd6}: color = SCARED_BLUE;
            {3'd3, 3'd2}, {3'd3, 3'd7}: color = WHITE;
            {3'd4, 3'd0}, {3'd4, 3'd1}, {3'd4, 3'd2}, {3'd4, 3'd3}, {3'd4, 3'd4}, {3'd4, 3'd5}, {3'd4, 3'd6}, {3'd4, 3'd7}: color = SCARED_BLUE;
            {3'd5, 3'd2}, {3'd5, 3'd3}, {3'd5, 3'd4}, {3'd5, 3'd5}: color = WHITE;
            {3'd6, 3'd0}, {3'd6, 3'd1}, {3'd6, 3'd2}, {3'd6, 3'd3}, {3'd6, 3'd4}, {3'd6, 3'd5}, {3'd6, 3'd6}, {3'd6, 3'd7}: begin
                case (anim_frame)
                    2'b00: begin
                        if ((px >= 3'd1 && px <= 3'd3) || (px >= 3'd5 && px <= 3'd6))
                            color = SCARED_BLUE;
                        else
                            color = BLACK;
                    end
                    2'b01: begin
                        if ((px >= 3'd2 && px <= 3'd3) || (px >= 3'd5 && px <= 3'd6))
                            color = SCARED_BLUE;
                        else
                            color = BLACK;
                    end
                    2'b10: begin
                        if ((px >= 3'd2 && px <= 3'd3) || (px >= 3'd5 && px <= 3'd7))
                            color = SCARED_BLUE;
                        else
                            color = BLACK;
                    end
                    default: color = BLACK;
                endcase
            end
            default: color = BLACK;
        endcase
    end else begin
        case ({py, px})
            {3'd1, 3'd3}, {3'd1, 3'd4}, {3'd1, 3'd5}: color = BROWN;
            {3'd2, 3'd2}, {3'd2, 3'd3}, {3'd2, 3'd4}, {3'd2, 3'd5}, {3'd2, 3'd6}: color = BROWN;
            {3'd3, 3'd1}, {3'd3, 3'd2}, {3'd3, 3'd4}, {3'd3, 3'd6}, {3'd3, 3'd7}: color = BROWN;
            {3'd3, 3'd3}, {3'd3, 3'd5}: color = BLACK;
            {3'd4, 3'd1}, {3'd4, 3'd3}, {3'd4, 3'd4}, {3'd4, 3'd5}: color = BROWN;
            {3'd4, 3'd2}, {3'd4, 3'd6}: color = WHITE;
            {3'd5, 3'd2}, {3'd5, 3'd3}, {3'd5, 3'd4}, {3'd5, 3'd5}: color = TAN;
            {3'd6, 3'd0}, {3'd6, 3'd1}, {3'd6, 3'd2}, {3'd6, 3'd3}, {3'd6, 3'd4}, {3'd6, 3'd5}, {3'd6, 3'd6}, {3'd6, 3'd7}: begin
                case (anim_frame)
                    2'b00: begin
                        if ((px >= 3'd1 && px <= 3'd3) || (px >= 3'd5 && px <= 3'd6))
                            color = BROWN;
                        else
                            color = BLACK;
                    end
                    2'b01: begin
                        if ((px >= 3'd2 && px <= 3'd3) || (px >= 3'd5 && px <= 3'd6))
                            color = BROWN;
                        else
                            color = BLACK;
                    end
                    2'b10: begin
                        if ((px >= 3'd2 && px <= 3'd3) || (px >= 3'd5 && px <= 3'd7))
                            color = BROWN;
                        else
                            color = BLACK;
                    end
                    default: color = BLACK;
                endcase
            end
            default: color = BLACK;
        endcase
    end
end
endmodule