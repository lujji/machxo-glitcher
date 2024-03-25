module glitcher (
    input wire clk_12M,         // 12M clock from FTDI/X1 crystal
    input wire rstn,            // from SW1 pushbutton
    input wire [2:0] DIPSW,     // input wire [3:0] DIPSW
    input wire rx,
    input wire trigger,

    output wire tx,
    output wire glitcher_out,
    output wire rst_out,
    output wire [7:0] LED       // LEDs (D2-D9)
    );

`define TRIGGER_RISING_EDGE

wire rst;
wire clk, clk_HS;

reg [7:0] led;

/* UART TX module */
wire tx_done;
reg [7:0] txd;
reg tx_trigger;

/* UART RX module */
parameter CMD_SET_HOLDOFF   = 8'h52;
parameter CMD_SET_WIDTH	    = 8'h53;
parameter CMD_SET_TRIGGER	= 8'h54;
parameter CMD_ARM           = 8'hFA;
parameter CMD_DISARM        = 8'hFB;
parameter CMD_INFO          = 8'hFC;
parameter CMD_INFO_REPLY    = 8'hDE;

parameter RX_STATE_IDLE     = 2'd0;
parameter RX_STATE_HOLDOFF  = 2'd1;
parameter RX_STATE_WIDTH    = 2'd2;
parameter RX_STATE_TRIGGER    = 2'd3;

wire rx_ready;
wire [7:0] rxd;

reg [1:0] rx_state;
reg [7:0] rx_val_buf [0:6];
reg [3:0] rx_byte_ctr;

reg [7:0] boot_ctr;
reg [23:0] led_ctr;

reg [31:0] holdoff_value;
reg [31:0] trigger_value;
reg [63:0] width_value;
reg armed;
reg on_state;
reg rst_on_state;
reg idle_state;

always @ (posedge clk or posedge rst)
begin
    if (rst) begin
        led <= 8'd0;

        rx_byte_ctr <= 4'd0;
        rx_state <= RX_STATE_IDLE;
        width_value <= 64'd2800; // 11.5us
        holdoff_value <= 32'd100;
        trigger_value <= 32'd50;
        armed <= 1'b0;
        boot_ctr <= 8'd0;

        idle_state <= 1'b0;
        on_state <= 1'b0;
        rst_on_state <= 1'b0;

        led_ctr <= 24'd0;
    end else begin
        led_ctr <= led_ctr + 24'd1;

        /* version reply on boot */
        if (boot_ctr == 8'd0) begin
            txd <= "G";
            tx_trigger <= 1'b1;
            boot_ctr <= 8'd1;
        end else if (boot_ctr == 8'd16) begin
            if (tx_trigger == 1'b1 && tx_done == 1'b1) begin
                tx_trigger <= 1'b0;
            end
        end else if (tx_done == 1'b1) begin
            if (boot_ctr == 8'd1)        txd <= "l";
            else if (boot_ctr == 8'd2)   txd <= "i";
            else if (boot_ctr == 8'd3)   txd <= "t";
            else if (boot_ctr == 8'd4)   txd <= "c";
            else if (boot_ctr == 8'd5)   txd <= "h";
            else if (boot_ctr == 8'd6)   txd <= "e";
            else if (boot_ctr == 8'd7)   txd <= "r";
            else if (boot_ctr == 8'd8)   txd <= ":";
            else if (boot_ctr == 8'd9)   txd <= "R";
            else if (boot_ctr == 8'd10)  txd <= "E";
            else if (boot_ctr == 8'd11)  txd <= "-";
            else if (boot_ctr == 8'd12)  txd <= "1";
            else if (boot_ctr == 8'd13)  txd <= "9";
            else if (boot_ctr == 8'd14)  txd <= "2";
            else if (boot_ctr == 8'd15)  txd <= "\n";
            //else begin tx_trigger <= 1'b0; end
            boot_ctr <= boot_ctr + 8'd1;
        end

        /* reception */
        if (rx_ready) begin
            if (rx_state == RX_STATE_IDLE) begin
                rx_byte_ctr <= 4'd0;
                case (rxd)
                    CMD_SET_HOLDOFF:    rx_state <= RX_STATE_HOLDOFF;
                    CMD_SET_WIDTH:      rx_state <= RX_STATE_WIDTH;
                    CMD_SET_TRIGGER:    rx_state <= RX_STATE_TRIGGER;
                    CMD_ARM:            armed <= 1'b1;
                    CMD_DISARM:         armed <= 1'b0;
                    CMD_INFO:           begin txd <= CMD_INFO_REPLY; tx_trigger <= 1'b1; end
                    default:            rx_state <= RX_STATE_IDLE;
                endcase
            end else begin
                if ((rx_byte_ctr == 4'd7) && (rx_state == RX_STATE_WIDTH)) begin
                    width_value <= { rx_val_buf[0], rx_val_buf[1], rx_val_buf[2], rx_val_buf[3],
                                     rx_val_buf[4], rx_val_buf[5], rx_val_buf[6], rxd };

                    rx_byte_ctr <= 4'd0;
                    rx_state <= RX_STATE_IDLE;
                end else if ((rx_byte_ctr == 4'd3) && (rx_state != RX_STATE_WIDTH)) begin
                    /* last byte */
                    if (rx_state == RX_STATE_HOLDOFF)
                        holdoff_value <= { rx_val_buf[0], rx_val_buf[1], rx_val_buf[2], rxd };
                    else
                        trigger_value = { rx_val_buf[0], rx_val_buf[1], rx_val_buf[2], rxd };

                    rx_byte_ctr <= 4'd0;
                    rx_state <= RX_STATE_IDLE;
                end else begin
                    rx_val_buf[rx_byte_ctr] <= rxd;
                    rx_byte_ctr <= rx_byte_ctr + 4'd1;
                end
            end
        end

        led[7] <= DIPSW[0];
        led[6] <= DIPSW[1];
        led[5] <= DIPSW[2];
        led[0] <= (led_ctr == 0) ? ~led[0] : led[0];

        idle_state <= DIPSW[0];
        on_state <= DIPSW[1];
        rst_on_state <= DIPSW[2];

        // if (glitcher_done)
        //     armed <= 1'b0;
    end
end

assign LED = ~led;
assign rst = ~rstn;

uart_rx #(.clk_freq (12000000)) UART_RX_inst(clk, rst, rx, rx_ready, rxd);
uart_tx #(.clk_freq (12000000)) UART_TX_inst(clk, tx_trigger, txd, tx, tx_done);

wire [0:1] gout;

wire ODDRXE_DUMMY_RST;
ODDRXE ODDRXE_inst (
    .D0(gout[0]),
    .D1(gout[1]),
    .SCLK(clk_HS),
    .RST(ODDRXE_DUMMY_RST),

    .Q(glitcher_out)
    );

pll PLL_inst (
    .CLKI(clk_12M),
    .CLKOS(clk_HS),
    .CLKOP(clk)
    );

wire glitcher_done;
glitch_pattern GLITCH_inst (
    clk_HS, armed, idle_state, on_state, rst_on_state, trigger,
    holdoff_value, width_value, trigger_value,
    gout, rst_out, glitcher_done
    );

// glitch_pulse GLITCH_inst (
// 	clk_HS, armed, idle_state, on_state, rst_on_state, holdoff_value, width_value[31:0],
//     gout, rst_out, glitcher_done
// 	);

endmodule
