module glitch (
    input wire clk,
    input wire armed,
    input wire inverse,
    input wire always_on,
    input wire [31:0] holdoff,
    input wire [31:0] pulse_width,

    output reg out,
    output reg dbg,
    output reg rdy
    );

    parameter STATE_HOLDOFF = 2'b00;
    parameter STATE_GLITCH  = 2'b01;
    parameter STATE_DONE    = 2'b10;

    reg [31:0] counter;
    reg [1:0] state;

    always @ (posedge clk)
    begin
        if (armed == 1'b1) begin
            dbg <= ~dbg;
            //dbg <= 1'b0;
            if (state == STATE_HOLDOFF) begin
                out <= 1'b1;

                if (counter == holdoff) begin
                    counter <= 32'd0;
                    state <= STATE_GLITCH;
                end else begin
                    counter <= counter + 32'd1;
                end
            end else if (state == STATE_GLITCH) begin
                if (counter == pulse_width) begin
                    counter <= 32'd0;
                    out <= 1'b1;
                    state <= STATE_DONE;
                end else begin
                    counter <= counter + 32'd1;
                    out <= 1'b0;
                end
            end else begin
                rdy <= 1'b1;
                out <= 1'b1;
            end
        end else begin
            state <= STATE_HOLDOFF;
            counter <= 32'd0;
            out <= always_on ? 1'b1 : 1'b0; // default = 0
            dbg <= 1'b1;
            rdy <= 1'b0;
        end
    end
endmodule
