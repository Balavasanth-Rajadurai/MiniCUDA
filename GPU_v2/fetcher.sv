`default_nettype none
`timescale 1ns/1ns

module fetcher #(
    parameter PROGRAM_MEM_ADDR_BITS = 8,
    parameter PROGRAM_MEM_DATA_BITS = 16,
    parameter THREADS_PER_BLOCK = 4
) (
    input  wire clk,
    input  wire reset,

    input  wire [2:0] core_state,
    input  wire [PROGRAM_MEM_ADDR_BITS-1:0] current_pc [THREADS_PER_BLOCK-1:0],

    input  wire [THREADS_PER_BLOCK-1:0] active_mask,  

    output reg mem_read_valid,
    output reg [PROGRAM_MEM_ADDR_BITS-1:0] mem_read_address,
    input  wire mem_read_ready,
    input  wire [PROGRAM_MEM_DATA_BITS-1:0] mem_read_data,

    output reg [2:0] fetcher_state,
    output reg [PROGRAM_MEM_DATA_BITS-1:0] instruction [THREADS_PER_BLOCK-1:0]
);

    localparam IDLE     = 3'b000,
               FETCHING = 3'b001,
               FETCHED  = 3'b010;

    integer i;
    reg [1:0] thread_index;

    always @(posedge clk) begin
        if (reset) begin
            fetcher_state     <= IDLE;
            mem_read_valid    <= 1'b0;
            mem_read_address  <= {PROGRAM_MEM_ADDR_BITS{1'b0}};
            thread_index      <= 0;
            for (i = 0; i < THREADS_PER_BLOCK; i = i + 1) begin
                instruction[i] <= 0;
            end
        end else begin
            case (fetcher_state)
                IDLE: begin
                    if (core_state == 3'b001) begin 
                        thread_index <= 0;

                        while (thread_index < THREADS_PER_BLOCK && !active_mask[thread_index])
                            thread_index = thread_index + 1;

                        if (thread_index < THREADS_PER_BLOCK) begin
                            mem_read_valid   <= 1'b1;
                            mem_read_address <= current_pc[thread_index];
                            fetcher_state    <= FETCHING;
                        end
                    end
                end

                FETCHING: begin
                    if (mem_read_ready) begin
                        instruction[thread_index] <= mem_read_data;

                        thread_index = thread_index + 1;
                        while (thread_index < THREADS_PER_BLOCK && !active_mask[thread_index])
                            thread_index = thread_index + 1;

                        if (thread_index < THREADS_PER_BLOCK) begin
                            mem_read_address <= current_pc[thread_index];
                        end else begin
                            mem_read_valid  <= 1'b0;
                            fetcher_state   <= FETCHED;
                        end
                    end
                end

                FETCHED: begin
                    if (core_state == 3'b010) begin 
                        fetcher_state <= IDLE;
                    end
                end

                default: fetcher_state <= IDLE;
            endcase
        end
    end

endmodule

