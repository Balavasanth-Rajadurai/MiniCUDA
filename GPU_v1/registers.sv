`default_nettype none
`timescale 1ns/1ns

module registers #(
    parameter THREADS_PER_BLOCK = 4,
    parameter THREAD_ID = 0,
    parameter DATA_BITS = 8
) (
    input wire clk,
    input wire reset,
    input wire enable, 

    input wire [7:0] block_id,

    input wire [2:0] core_state,

    input wire [3:0] decoded_rd_address,
    input wire [3:0] decoded_rs_address,
    input wire [3:0] decoded_rt_address,

    input wire decoded_reg_write_enable,
    input wire [1:0] decoded_reg_input_mux,
    input wire [DATA_BITS-1:0] decoded_immediate,

    input wire [DATA_BITS-1:0] alu_out,
    input wire [DATA_BITS-1:0] lsu_out,

    output reg [7:0] rs,
    output reg [7:0] rt,

    input wire thread_active
);

    localparam ARITHMETIC = 2'b00,
               MEMORY     = 2'b01,
               CONSTANT   = 2'b10;

    reg [7:0] registers [15:0];

    reg block_id_loaded;

    integer i;

    always @(posedge clk) begin
        if (reset) begin
            rs <= 0;
            rt <= 0;
            block_id_loaded <= 0;

            for (i = 0; i < 16; i = i + 1)
                registers[i] <= 8'b0;

            registers[14] <= THREADS_PER_BLOCK; // %blockDim
            registers[15] <= THREAD_ID;         // %threadIdx

        end else if (enable) begin
            // One-time load of %blockIdx into R13
            if (!block_id_loaded) begin
                registers[13] <= block_id;
                block_id_loaded <= 1;
            end

            if (core_state == 3'b111)
                block_id_loaded <= 0;

            if (core_state == 3'b011) begin
                if (thread_active) begin
                    rs <= registers[decoded_rs_address];
                    rt <= registers[decoded_rt_address];
                end else begin
                    rs <= 8'b0;
                    rt <= 8'b0;
                end
            end

            if (core_state == 3'b110 && thread_active) begin
                if (decoded_reg_write_enable && decoded_rd_address < 13) begin
                    case (decoded_reg_input_mux)
                        ARITHMETIC: registers[decoded_rd_address] <= alu_out;
                        MEMORY:     registers[decoded_rd_address] <= lsu_out;
                        CONSTANT:   registers[decoded_rd_address] <= decoded_immediate;
                        default:    registers[decoded_rd_address] <= 8'b0;
                    endcase
                end
            end
        end
    end

endmodule

