
`default_nettype none
`timescale 1ns/1ns

module alu #(
    parameter THREADS_PER_BLOCK = 4
) (
    input  wire clk,
    input  wire reset,
    input  wire enable, 
    input  wire [2:0] core_state,

    input  wire [1:0] decoded_alu_arithmetic_mux,
    input  wire       decoded_alu_output_mux,

    input  wire [7:0] rs [THREADS_PER_BLOCK-1:0],
    input  wire [7:0] rt [THREADS_PER_BLOCK-1:0],
    output wire [7:0] alu_out [THREADS_PER_BLOCK-1:0]
);

    localparam ADD = 2'b00,
               SUB = 2'b01,
               MUL = 2'b10,
               DIV = 2'b11;

    reg [7:0] alu_out_reg [THREADS_PER_BLOCK-1:0];
    assign alu_out = alu_out_reg;

    integer i;

    always @(posedge clk) begin 
        if (reset) begin 
            for (i = 0; i < THREADS_PER_BLOCK; i = i + 1)
                alu_out_reg[i] <= 8'b0;

        end else if (enable && core_state == 3'b101) begin // EXECUTE state

            for (i = 0; i < THREADS_PER_BLOCK; i = i + 1) begin
                if (decoded_alu_output_mux) begin
                    if ((rs[i] - rt[i]) > 0)
                        alu_out_reg[i] <= 8'b0000_0001; // P
                    else if ((rs[i] - rt[i]) == 0)
                        alu_out_reg[i] <= 8'b0000_0010; // Z
                    else
                        alu_out_reg[i] <= 8'b0000_0100; // N

                end else begin
                    case (decoded_alu_arithmetic_mux)
                        ADD: alu_out_reg[i] <= rs[i] + rt[i];
                        SUB: alu_out_reg[i] <= rs[i] - rt[i];
                        MUL: alu_out_reg[i] <= rs[i] * rt[i];
                        DIV: alu_out_reg[i] <= (rt[i] != 0) ? rs[i] / rt[i] : 8'b0;
                        default: alu_out_reg[i] <= 8'b0;
                    endcase
                end
            end
        end
    end

endmodule

