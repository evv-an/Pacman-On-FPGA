module tilemap_rom (
    input  [4:0] tile_x, // 0 to 19
    input  [3:0] tile_y, // 0 to 14
    output reg is_wall
);

reg[19:0] row_data;

	always @(*) begin
        case(tile_y)
          4'd0:  row_data = 20'b11111111101111111111; // array
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
		 is_wall = row_data[19 - tile_x];
    end
endmodule