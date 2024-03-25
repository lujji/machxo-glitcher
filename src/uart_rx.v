module uart_rx (
    input wire clk,
    input wire rst,
    input wire i_rx,

    output wire o_data_ready,
    output wire [7:0] o_rx_byte
    );

    parameter clk_freq = 12000000; // input clock in Hz
    parameter baudrate = 115200;
    parameter [15:0] timebase = clk_freq / baudrate;

    reg [15:0] ctr;     // timebase counter
    reg [3:0] bit;      // current RX bit
    reg [7:0] rx_byte;  // received byte
    reg rx, rx_;        // buffer registers
    reg start_bit;      // waiting for start bit?
    reg data_ready;

    always @ (posedge clk or posedge rst)
    begin
        if (rst) begin
            ctr <= 16'd0;
            bit <= 4'd0;
            data_ready <= 1'b0;
            rx_byte <= 8'd0;
            start_bit <= 1'b1;
            rx <= 1'b0;
            rx_ <= 1'b0;
        end else begin
            /* double buffer register */
            rx_ <= i_rx;
            rx <= rx_;

            if (start_bit) begin
                data_ready <= 1'b0;
                if (ctr == (timebase - 1) / 2) begin
                    start_bit <= 1'b0;
                    ctr <= 16'd0;
                end else begin
                    ctr <= rx ? 16'd0 : ctr + 16'd1;
                end
            end else begin
                if (ctr == timebase - 1) begin
                    if (bit == 4'd8) begin
                        /* stop bit */
                        data_ready <= rx; // set if stop bit is present
                        bit <= 4'd0;
                        start_bit <= 1'b1;
                    end else begin
                        /* regular bit */
                        rx_byte[bit] <= rx;
                        bit <= bit + 4'd1;
                    end

                    ctr <= 16'd0;
                end else begin
                    ctr <= ctr + 16'd1;
                end
            end
        end
    end

    assign o_rx_byte = rx_byte;
    assign o_data_ready = data_ready;
endmodule
