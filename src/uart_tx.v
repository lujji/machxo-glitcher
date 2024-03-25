module uart_tx (
    input wire clk,
    input wire trigger,
    input wire [7:0] tx_byte,

    output wire o_tx,
    output wire o_tx_done
    );

    parameter clk_freq = 12000000; // input clock in Hz
    parameter baudrate = 115200;
    parameter [15:0] timebase = clk_freq / baudrate;

    reg [15:0] ctr; // timebase counter
    reg [3:0] bit;  // current RX bit

    reg tx_done;
    reg tx;

    always @ (posedge clk)
    begin
        if (trigger == 1'b1) begin
            if (ctr == timebase) begin
                if (bit == 4'd10) begin
                    /* done - prepare for next byte */
                    tx_done <= 1'b1;
                    ctr <= timebase - 1; // allow one cycle to sync
                    bit <= 4'd0;
                end else begin
                    tx_done <= 1'b0;
                    ctr <= 16'd0;
                    if (bit == 4'd0) begin
                        /* start bit */
                        tx <= 1'b0;
                        bit <= 4'd1;
                    end else if (bit == 4'd9) begin
                        /* stop bit */
                        tx <= 1'b1;
                        bit <= 4'd10;
                    end else begin
                        /* data bit */
                        tx <= tx_byte[bit - 4'd1];
                        bit <= bit + 4'd1;
                    end
                end
            end else begin
                tx_done <= 1'b0;
                ctr <= ctr + 16'd1;
            end
        end else begin
            ctr <= timebase;
            bit <= 4'd0;
            tx_done <= 1'b0;
            tx <= 1'b1;
        end
    end

    assign o_tx = tx;
    assign o_tx_done = tx_done;
endmodule
