module tilemap_rom (
    input        level,  // 0: Level 1, 1: Level 2
    input  [4:0] tile_x, // 0 to 19
    input  [3:0] tile_y, // 0 to 14
    output reg   is_wall
);

reg [19:0] row_data;

always @(*) begin
    if (level == 1'b0) begin
        //level 1 map
        case(tile_y)
            4'd0:  row_data = 20'b11111111101111111111;
            4'd1:  row_data = 20'b10000011101110000001;
            4'd2:  row_data = 20'b10101000000000101101;
            4'd3:  row_data = 20'b10101011101110100001;
            4'd4:  row_data = 20'b10000010000000001101;
            4'd5:  row_data = 20'b10101010111010100101;
            4'd6:  row_data = 20'b10001000101010110101;
            4'd7:  row_data = 20'b11101110101010000001;
            4'd8:  row_data = 20'b10001000101010110101;
            4'd9:  row_data = 20'b10101010111010100101;
            4'd10: row_data = 20'b10000010000000001101;
            4'd11: row_data = 20'b10101011101110100001;
            4'd12: row_data = 20'b10101000000000101101;
            4'd13: row_data = 20'b10000011101110000001;
            4'd14: row_data = 20'b11111111101111111111;
            default: row_data = 20'b0;
        endcase
    end else begin
        //level 2 map
        case(tile_y)
            4'd0:  row_data = 20'b11111111101111111111;
            4'd1:  row_data = 20'b10000000000000100001;
            4'd2:  row_data = 20'b10101101110110101101;
            4'd3:  row_data = 20'b10000101000000000101;
            4'd4:  row_data = 20'b11010000011101110001;
            4'd5:  row_data = 20'b11011010111000100101;
            4'd6:  row_data = 20'b10000010101010001101;
            4'd7:  row_data = 20'b10110110101010100001;
            4'd8:  row_data = 20'b10000010101010001101;
            4'd9:  row_data = 20'b11011010111000100101;
            4'd10: row_data = 20'b11010000011101110001;
            4'd11: row_data = 20'b10000101000000000101;
            4'd12: row_data = 20'b10101101110110101101;
            4'd13: row_data = 20'b10000000000000100001;
            4'd14: row_data = 20'b11111111101111111111;
            default: row_data = 20'b0;
        endcase
    end
    is_wall = row_data[19 - tile_x];
end
endmodule