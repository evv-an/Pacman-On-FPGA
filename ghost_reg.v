module ghost_reg (
    input clk,
    input rst,
    input en,
    input [12:0] ghost_count,
    output reg [12:0] ghost_score);

always @ (posedge clk or negedge rst) 
begin
    if (rst == 1'b0) begin
        ghost_score <= 13'd0;
    end else if (en == 1'b1) begin
        case (ghost_count)
            13'd1: ghost_score <= ghost_score + 13'd200;
            13'd2: ghost_score <= ghost_score + 13'd400;
            13'd3: ghost_score <= ghost_score + 13'd800;
            13'd4: ghost_score <= ghost_score + 13'd1600;
            default: ghost_score <= ghost_score;
        endcase
    end
end

endmodule