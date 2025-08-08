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

    // FSM States
    localparam IDLE    = 3'b000,
               FETCH   = 3'b001,
               DECODE  = 3'b010,
               REQUEST = 3'b011,
               WAIT    = 3'b100,
               EXECUTE = 3'b101,
               UPDATE  = 3'b110,
               DONE    = 3'b111;

    // Control signals and stacks
    reg [THREADS_PER_BLOCK-1:0] active_mask;

    reg [7:0] pc_stack [STACK_DEPTH-1:0][THREADS_PER_BLOCK-1:0];
    reg [THREADS_PER_BLOCK-1:0] mask_stack [STACK_DEPTH-1:0];
    reg [4:0] sp;

    // Temp regs for divergence handling
    reg [THREADS_PER_BLOCK-1:0] branch_taken;
    reg [THREADS_PER_BLOCK-1:0] taken_mask;
    reg [THREADS_PER_BLOCK-1:0] fallthrough_mask;

    integer i;

    always @(posedge clk) begin
        if (reset) begin
            core_state <= IDLE;
            done <= 0;
            sp <= 0;
            active_mask <= {THREADS_PER_BLOCK{1'b1}};
            for (i = 0; i < THREADS_PER_BLOCK; i = i + 1) begin
                current_pc[i] <= 8'd0;
            end
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
                    if (!any_waiting) core_state <= EXECUTE;
                end

                EXECUTE: begin
                    core_state <= UPDATE;
                end

                UPDATE: begin
                    // Evaluate which threads take the branch
                    for (i = 0; i < THREADS_PER_BLOCK; i = i + 1) begin
                        if (decoded_pc_mux && ((alu_nzp[i] & decoded_nzp) != 3'b000))
                            branch_taken[i] = 1'b1;
                        else
                            branch_taken[i] = 1'b0;
                    end

                    taken_mask = branch_taken & active_mask;
                    fallthrough_mask = ~branch_taken & active_mask;

                    // Save fallthrough path if needed
                    if (fallthrough_mask != {THREADS_PER_BLOCK{1'b0}} && sp < STACK_DEPTH) begin
                        for (i = 0; i < THREADS_PER_BLOCK; i = i + 1) begin
                            pc_stack[sp][i] = next_pc[i];
                        end
                        mask_stack[sp] = fallthrough_mask;
                        sp = sp + 1;
                    end

                    // Execute taken path
                    if (taken_mask != {THREADS_PER_BLOCK{1'b0}}) begin
                        for (i = 0; i < THREADS_PER_BLOCK; i = i + 1) begin
                            if (taken_mask[i])
                                current_pc[i] <= decoded_immediate;
                        end
                        active_mask <= taken_mask;
                        core_state <= FETCH;
                    end
                    else if (sp > 0) begin
                        // Restore fallthrough path
                        sp = sp - 1;
                        for (i = 0; i < THREADS_PER_BLOCK; i = i + 1) begin
                            current_pc[i] <= pc_stack[sp][i];
                        end
                        active_mask <= mask_stack[sp];
                        core_state <= FETCH;
                    end
                    else if (decoded_ret) begin
                        core_state <= DONE;
                        done <= 1;
                    end else begin
                        core_state <= FETCH;
                    end
                end

                DONE: begin
                    // Remain in DONE state
                end
            endcase
        end
    end
endmodule


