`default_nettype none
`timescale 1ns/1ns

module scheduler #(
    parameter THREADS_PER_BLOCK = 4,
    parameter STACK_DEPTH = 32
) (
    input wire clk,
    input wire reset,
    input wire start,

    input wire decoded_mem_read_enable,
    input wire decoded_mem_write_enable,
    input wire decoded_ret,
    input wire decoded_pc_mux,
    input wire decoded_barrier_enable,
    input wire [2:0] decoded_nzp,
    input wire [7:0] decoded_immediate,

    input wire [2:0] fetcher_state,
    input wire [1:0] lsu_state [THREADS_PER_BLOCK-1:0],
    input wire [2:0] alu_nzp [THREADS_PER_BLOCK-1:0],

    output reg [7:0] current_pc [THREADS_PER_BLOCK-1:0],
    input wire [7:0] next_pc [THREADS_PER_BLOCK-1:0],

    output reg [2:0] core_state,
    output reg done
);

    localparam IDLE    = 3'b000,
               FETCH   = 3'b001,
               DECODE  = 3'b010,
               REQUEST = 3'b011,
               WAIT    = 3'b100,
               EXECUTE = 3'b101,
               UPDATE  = 3'b110,
               DONE    = 3'b111;

    reg [THREADS_PER_BLOCK-1:0] active_mask;
    reg [THREADS_PER_BLOCK-1:0] barrier_flags;
    integer barrier_count;

    reg [7:0] pc_stack [STACK_DEPTH-1:0][THREADS_PER_BLOCK-1:0];
    reg [THREADS_PER_BLOCK-1:0] mask_stack [STACK_DEPTH-1:0];
    reg [4:0] sp;

    reg [THREADS_PER_BLOCK-1:0] branch_taken;
    reg [THREADS_PER_BLOCK-1:0] taken_mask;
    reg [THREADS_PER_BLOCK-1:0] fallthrough_mask;

    integer i;

    always @(posedge clk) begin
        if (reset) begin
            core_state <= IDLE;
            done <= 0;
            sp <= 0;
            barrier_flags <= 0;
            barrier_count <= 0;
            active_mask <= {THREADS_PER_BLOCK{1'b1}};
            for (i = 0; i < THREADS_PER_BLOCK; i = i + 1)
                current_pc[i] <= 8'd0;

        end else begin
            case (core_state)
                IDLE: begin
                    if (start) begin
                        core_state <= FETCH;
                        done <= 0;
                    end
                end

                FETCH: begin
                    if (fetcher_state == 3'b010) begin
                        core_state <= DECODE;
                    end
                end

                DECODE: begin
                    core_state <= REQUEST;
                end

                REQUEST: begin
                    if (decoded_barrier_enable) begin
                        for (i = 0; i < THREADS_PER_BLOCK; i = i + 1) begin
                            if (active_mask[i] && !barrier_flags[i]) begin
                                barrier_flags[i] <= 1;
                                barrier_count <= barrier_count + 1;
                            end
                        end
                    end
                    core_state <= WAIT;
                end

                WAIT: begin
                    reg any_waiting;
                    any_waiting = 0;

                    for (i = 0; i < THREADS_PER_BLOCK; i = i + 1) begin
                        if (active_mask[i] && (lsu_state[i] == 2'b01 || lsu_state[i] == 2'b10)) begin
                            any_waiting = 1;
                        end
                    end

                    if (decoded_barrier_enable) begin
                        if (barrier_count == THREADS_PER_BLOCK) begin
                            barrier_flags <= 0;
                            barrier_count <= 0;
                            core_state <= EXECUTE;
                        end
                    end else if (!any_waiting) begin
                        core_state <= EXECUTE;
                    end
                end

                EXECUTE: begin
                    core_state <= UPDATE;
                end

                UPDATE: begin
                    for (i = 0; i < THREADS_PER_BLOCK; i = i + 1) begin
                        if (decoded_pc_mux && ((alu_nzp[i] & decoded_nzp) != 3'b000))
                            branch_taken[i] = 1;
                        else
                            branch_taken[i] = 0;
                    end

                    taken_mask       = branch_taken & active_mask;
                    fallthrough_mask = ~branch_taken & active_mask;

                    if (fallthrough_mask != {THREADS_PER_BLOCK{1'b0}} && sp < STACK_DEPTH) begin
                        for (i = 0; i < THREADS_PER_BLOCK; i = i + 1)
                            pc_stack[sp][i] = next_pc[i];
                        mask_stack[sp] = fallthrough_mask;
                        sp = sp + 1;
                    end

                    if (taken_mask != {THREADS_PER_BLOCK{1'b0}}) begin
                        for (i = 0; i < THREADS_PER_BLOCK; i = i + 1)
                            if (taken_mask[i])
                                current_pc[i] <= decoded_immediate;
                        active_mask <= taken_mask;
                        core_state <= FETCH;

                    end else if (sp > 0) begin
                        sp = sp - 1;
                        for (i = 0; i < THREADS_PER_BLOCK; i = i + 1)
                            current_pc[i] <= pc_stack[sp][i];
                        active_mask <= mask_stack[sp];
                        core_state <= FETCH;

                    end else if (decoded_ret) begin
                        core_state <= DONE;
                        done <= 1;

                    end else begin
                        for (i = 0; i < THREADS_PER_BLOCK; i = i + 1)
                            current_pc[i] <= next_pc[i];
                        core_state <= FETCH;
                    end
                end

                DONE: begin

                end
            endcase
        end
    end
endmodule

