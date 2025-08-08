
`default_nettype none
`timescale 1ns/1ns

module core #(
    parameter DATA_MEM_ADDR_BITS = 8,
    parameter DATA_MEM_DATA_BITS = 8,
    parameter PROGRAM_MEM_ADDR_BITS = 8,
    parameter PROGRAM_MEM_DATA_BITS = 16,
    parameter THREADS_PER_BLOCK = 4
)(
    input wire clk,
    input wire reset,
    input wire start,
    output wire done,

    input wire [7:0] block_id,
    input wire [$clog2(THREADS_PER_BLOCK):0] thread_count,

    // Program memory interface (shared)
    output wire program_mem_read_valid,
    output wire [PROGRAM_MEM_ADDR_BITS-1:0] program_mem_read_address,
    input  wire program_mem_read_ready,
    input  wire [PROGRAM_MEM_DATA_BITS-1:0] program_mem_read_data,

    // Data memory interface (per-thread)
    output wire [THREADS_PER_BLOCK-1:0] data_mem_read_valid,
    output wire [DATA_MEM_ADDR_BITS-1:0] data_mem_read_address [THREADS_PER_BLOCK-1:0],
    input  wire [THREADS_PER_BLOCK-1:0] data_mem_read_ready,
    input  wire [DATA_MEM_DATA_BITS-1:0] data_mem_read_data [THREADS_PER_BLOCK-1:0],
    output wire [THREADS_PER_BLOCK-1:0] data_mem_write_valid,
    output wire [DATA_MEM_ADDR_BITS-1:0] data_mem_write_address [THREADS_PER_BLOCK-1:0],
    output wire [DATA_MEM_DATA_BITS-1:0] data_mem_write_data [THREADS_PER_BLOCK-1:0],
    input  wire [THREADS_PER_BLOCK-1:0] data_mem_write_ready
);

    wire [2:0] core_state;
    wire [2:0] fetcher_state;
    wire [PROGRAM_MEM_DATA_BITS-1:0] instruction;

    wire [7:0] current_pc [THREADS_PER_BLOCK-1:0];
    wire [7:0] next_pc [THREADS_PER_BLOCK-1:0];
    wire [7:0] rs [THREADS_PER_BLOCK-1:0];
    wire [7:0] rt [THREADS_PER_BLOCK-1:0];
    wire [1:0] lsu_state [THREADS_PER_BLOCK-1:0];
    wire [7:0] lsu_out [THREADS_PER_BLOCK-1:0];
    wire [7:0] alu_out [THREADS_PER_BLOCK-1:0];
    wire [2:0] alu_nzp [THREADS_PER_BLOCK-1:0];
    wire [THREADS_PER_BLOCK-1:0] active_mask;

    wire [3:0] decoded_rd_address, decoded_rs_address, decoded_rt_address;
    wire [2:0] decoded_nzp;
    wire [7:0] decoded_immediate;
    wire       decoded_reg_write_enable, decoded_mem_read_enable, decoded_mem_write_enable;
    wire       decoded_nzp_write_enable, decoded_pc_mux, decoded_ret;
    wire [1:0] decoded_reg_input_mux, decoded_alu_arithmetic_mux;
    wire       decoded_alu_output_mux;
    wire decoded_barrier_enable;
    wire barrier_active;

    scheduler #(
        .THREADS_PER_BLOCK(THREADS_PER_BLOCK)
    ) scheduler_instance (
        .clk(clk),
        .reset(reset),
        .start(start),
        .core_state(core_state),
        .fetcher_state(fetcher_state),
        .decoded_mem_read_enable(decoded_mem_read_enable),
        .decoded_mem_write_enable(decoded_mem_write_enable),
        .decoded_ret(decoded_ret),
        .decoded_pc_mux(decoded_pc_mux),
        .decoded_nzp(decoded_nzp),
        .decoded_immediate(decoded_immediate),
        .alu_nzp(alu_nzp),
        .lsu_state(lsu_state),
        .current_pc(current_pc),
        .next_pc(next_pc),
        .active_mask(active_mask),
        .decoder_barrier_enable(decoded_barrier_enable), 
        .done(done)
    );

    fetcher #(
        .PROGRAM_MEM_ADDR_BITS(PROGRAM_MEM_ADDR_BITS),
        .PROGRAM_MEM_DATA_BITS(PROGRAM_MEM_DATA_BITS),
        .THREADS_PER_BLOCK(THREADS_PER_BLOCK)
    ) fetcher_instance (
        .clk(clk),
        .reset(reset),
        .core_state(core_state),
        .current_pc(current_pc),
        .mem_read_valid(program_mem_read_valid),
        .mem_read_address(program_mem_read_address),
        .mem_read_ready(program_mem_read_ready),
        .mem_read_data(program_mem_read_data),
        .fetcher_state(fetcher_state),
        .instruction(instruction)
    );

    decoder decoder_instance (
        .clk(clk),
        .reset(reset),
        .core_state(core_state),
        .instruction(instruction),
        .decoded_rd_address(decoded_rd_address),
        .decoded_rs_address(decoded_rs_address),
        .decoded_rt_address(decoded_rt_address),
        .decoded_nzp(decoded_nzp),
        .decoded_immediate(decoded_immediate),
        .decoded_reg_write_enable(decoded_reg_write_enable),
        .decoded_mem_read_enable(decoded_mem_read_enable),
        .decoded_mem_write_enable(decoded_mem_write_enable),
        .decoded_nzp_write_enable(decoded_nzp_write_enable),
        .decoded_reg_input_mux(decoded_reg_input_mux),
        .decoded_alu_arithmetic_mux(decoded_alu_arithmetic_mux),
        .decoded_alu_output_mux(decoded_alu_output_mux),
        .decoded_pc_mux(decoded_pc_mux),
        .decoder_barrier_enable(decoded_barrier_enable),
        .decoded_ret(decoded_ret)
    );

    genvar i;
    generate
        for (i = 0; i < THREADS_PER_BLOCK; i = i + 1) begin : thread_block

            alu #(
                .THREADS_PER_BLOCK(THREADS_PER_BLOCK)
            ) alu_instance (
                .clk(clk),
                .reset(reset),
                .enable(i < thread_count),
                .core_state(core_state),
                .decoded_alu_arithmetic_mux(decoded_alu_arithmetic_mux),
                .decoded_alu_output_mux(decoded_alu_output_mux),
                .rs(rs[i]),
                .rt(rt[i]),
                .alu_out(alu_out[i])
            );

            assign alu_nzp[i] = alu_out[i][2:0]; 

            lsu lsu_instance (
                .clk(clk),
                .reset(reset),
                .enable(i < thread_count),
                .core_state(core_state),
		.barrier_active(barrier_active),
                .decoded_mem_read_enable(decoded_mem_read_enable),
                .decoded_mem_write_enable(decoded_mem_write_enable),
                .mem_read_valid(data_mem_read_valid[i]),
                .mem_read_address(data_mem_read_address[i]),
                .mem_read_ready(data_mem_read_ready[i]),
                .mem_read_data(data_mem_read_data[i]),
                .mem_write_valid(data_mem_write_valid[i]),
                .mem_write_address(data_mem_write_address[i]),
                .mem_write_data(data_mem_write_data[i]),
                .mem_write_ready(data_mem_write_ready[i]),
                .rs(rs[i]),
                .rt(rt[i]),
                .lsu_state(lsu_state[i]),
                .lsu_out(lsu_out[i])
            );

            registers #(
                .THREADS_PER_BLOCK(THREADS_PER_BLOCK),
                .THREAD_ID(i),
                .DATA_BITS(DATA_MEM_DATA_BITS)
            ) register_instance (
                .clk(clk),
                .reset(reset),
                .enable(i < thread_count),
                .block_id(block_id),
                .core_state(core_state),
                .decoded_rd_address(decoded_rd_address),
                .decoded_rs_address(decoded_rs_address),
                .decoded_rt_address(decoded_rt_address),
                .decoded_reg_write_enable(decoded_reg_write_enable),
                .decoded_reg_input_mux(decoded_reg_input_mux),
                .decoded_immediate(decoded_immediate),
                .alu_out(alu_out[i]),
                .lsu_out(lsu_out[i]),
                .rs(rs[i]),
                .rt(rt[i]),
                .thread_active(active_mask[i])
            );

            pc #(
                .DATA_MEM_DATA_BITS(DATA_MEM_DATA_BITS),
                .PROGRAM_MEM_ADDR_BITS(PROGRAM_MEM_ADDR_BITS),
                .THREADS_PER_BLOCK(THREADS_PER_BLOCK)
            ) pc_instance (
                .clk(clk),
                .reset(reset),
                .enable(i < thread_count),
                .core_state(core_state),
                .decoded_nzp(decoded_nzp),
                .decoded_immediate(decoded_immediate),
                .decoded_nzp_write_enable(decoded_nzp_write_enable),
                .decoded_pc_mux(decoded_pc_mux),
                .alu_out(alu_out[i]),
                .current_pc(current_pc[i]),
                .next_pc(next_pc[i])
            );

        end
    endgenerate

endmodule

