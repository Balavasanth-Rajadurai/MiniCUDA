`default_nettype none
`timescale 1ns/1ns

module lsu (
    input  wire        clk,
    input  wire        reset,
    input  wire        enable,          
    input  wire        thread_active,  

    input  wire [2:0]  core_state,

    input  wire        decoded_mem_read_enable,
    input  wire        decoded_mem_write_enable,

    input  wire [7:0]  rs,             
    input  wire [7:0]  rt,              

    output reg         mem_read_valid,
    output reg [7:0]   mem_read_address,
    input  wire        mem_read_ready,
    input  wire [7:0]  mem_read_data,

    output reg         mem_write_valid,
    output reg [7:0]   mem_write_address,
    output reg [7:0]   mem_write_data,
    input  wire        mem_write_ready,
    
    input wire barrier_active,    

    output reg [1:0]   lsu_state,
    output reg [7:0]   lsu_out
);

    localparam IDLE    = 2'b00,
               REQUEST = 2'b01,
               WAIT    = 2'b10,
               DONE    = 2'b11;

    reg current_rw; 

    always @(posedge clk) begin
        if (reset) begin
            lsu_state         <= IDLE;
            lsu_out           <= 8'd0;

            mem_read_valid    <= 1'b0;
            mem_read_address  <= 8'd0;

            mem_write_valid   <= 1'b0;
            mem_write_address <= 8'd0;
            mem_write_data    <= 8'd0;

            current_rw        <= 1'b0;

        end else if (enable && thread_active) begin
            case (lsu_state)
                IDLE: begin
                    if (core_state == 3'b011 && !barrier_active) begin 
                        if (decoded_mem_read_enable) begin
                            current_rw       <= 1'b0;
                            mem_read_valid   <= 1'b1;
                            mem_read_address <= rs;
                            lsu_state        <= REQUEST;

                        end else if (decoded_mem_write_enable) begin
                            current_rw         <= 1'b1;
                            mem_write_valid    <= 1'b1;
                            mem_write_address  <= rs;
                            mem_write_data     <= rt;
                            lsu_state          <= REQUEST;
                        end
                    end
                end

                REQUEST: begin
                    lsu_state <= WAIT;
                end

                WAIT: begin
                    if (!current_rw && mem_read_ready) begin
                        mem_read_valid <= 1'b0;
                        lsu_out        <= mem_read_data;
                        lsu_state      <= DONE;

                    end else if (current_rw && mem_write_ready) begin
                        mem_write_valid <= 1'b0;
                        lsu_state       <= DONE;
                    end
                end

                DONE: begin
                    if (core_state == 3'b110) begin
                        lsu_state <= IDLE;
                    end
                end
            endcase

        end else begin
            mem_read_valid    <= 1'b0;
            mem_write_valid   <= 1'b0;
        end
    end

endmodule

