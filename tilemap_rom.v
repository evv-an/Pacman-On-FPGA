module tilemap_rom (
    input  [4:0] tile_x, // 0 to 19 (Columns)
    input  [3:0] tile_y, // 0 to 14 (Rows)
    output reg is_wall
);

reg[19:0] row_data;

	always @(*) begin
        case(tile_y)
          4'd0:  row_data = 20'b11111_11110_11111_11111; // array
          4'd1:  row_data = 20'b10000_01110_11100_00001;
          4'd2:  row_data = 20'b10101_00000_00001_01101;
          4'd3:  row_data = 20'b10101_11110_11101_00001;
          4'd4:  row_data = 20'b10100_01000_00001_01101;
          4'd5:  row_data = 20'b10101_01011_10101_00101;
          4'd6:  row_data = 20'b10001_00010_10101_10101;
          4'd7:  row_data = 20'b11101_11010_10100_00001;
          4'd8:  row_data = 20'b10001_00010_10101_10101;
          4'd9:  row_data = 20'b10101_01011_10101_00101;
          4'd10: row_data = 20'b10100_01000_00001_01101;
          4'd11: row_data = 20'b10101_11110_11101_00001;
          4'd12: row_data = 20'b10101_00000_00001_01101;
          4'd13: row_data = 20'b10000_01110_11100_00001;
          4'd14: row_data = 20'b11111_11110_11111_11111;
          default: row_data = 20'b0;
        endcase
		 is_wall = row_data[19 - tile_x];
    end
endmodule