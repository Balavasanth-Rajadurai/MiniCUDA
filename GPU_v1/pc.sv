
`default_nettype none
`timescale 1ns/1ns

module pc #(
    parameter DATA_MEM_DATA_BITS = 8,
    parameter PROGRAM_MEM_ADDR_BITS = 8,
    parameter THREADS_PER_BLOCK = 4
) (
    input wire clk,

    input wire reset,
    input wire enable,

    input wire [2:0] core_state,

    input wire [2:0] decoded_nzp,
    input wire [DATA_MEM_DATA_BITS-1:0] decoded_immediate,
    input wire decoded_nzp_write_enable,
    input wire decoded_pc_mux,

    input wire [DATA_MEM_DATA_BITS-1:0] alu_out [THREADS_PER_BLOCK-1:0],

    input wire [PROGRAM_MEM_ADDR_BITS-1:0] current_pc [THREADS_PER_BLOCK-1:0],
    output reg [PROGRAM_MEM_ADDR_BITS-1:0] next_pc [THREADS_PER_BLOCK-1:0]
);

    reg [2:0] nzp [THREADS_PER_BLOCK-1:0];

    integer i;

    always @(posedge clk) begin
        if (reset) begin
            for (i = 0; i < THREADS_PER_BLOCK; i = i + 1) begin
                next_pc[i] <= 0;
                nzp[i] <= 3'b000;
            end

        end else if (enable) begin
            if (core_state == 3'b110) begin
                if (decoded_nzp_write_enable) begin
                    for (i = 0; i < THREADS_PER_BLOCK; i = i + 1) begin
                        nzp[i] <= alu_out[i][2:0]; // Assume lower 3 bits hold NZP result
                    end
                end
            end

            if (core_state == 3'b101) begin
                for (i = 0; i < THREADS_PER_BLOCK; i = i + 1) begin
                    if (decoded_pc_mux) begin
                        if ((nzp[i] & decoded_nzp) != 3'b000) begin
                            next_pc[i] <= decoded_immediate; // Branch taken
                        end else begin
                            next_pc[i] <= current_pc[i] + 1; // Fall through
                        end
                    end else begin
                        next_pc[i] <= current_pc[i] + 1;
                    end
                end
            end
        end
    end

endmodule
