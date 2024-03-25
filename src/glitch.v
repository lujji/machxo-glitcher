module glitch_pattern (
    input wire clk,
    input wire armed,
    input wire idle_state,
    input wire on_state,
    input wire rst_on_state,
    input wire i_trigger,
    input wire [31:0] holdoff,
    input wire [63:0] pulse,
    input wire [11:0] pulse_target,

    output reg [0:1] out,
    output reg rst,
    output reg rdy
    );

    parameter STATE_HOLDOFF = 2'b00;
    parameter STATE_GLITCH  = 2'b01;
    parameter STATE_DONE    = 2'b10;

    reg [31:0] counter;
    reg [5:0] pattern_ctr;
    reg [1:0] state;

    reg trigger_buf;
    reg trigger;
    reg go;

    reg [11:0] pulse_ctr;
    reg pulse_ctr_stop;
    reg trigger_prev;

`ifdef TRIGGER_RISING_EDGE
    /* trigger on RISING edge - single shot */
    always @ (posedge clk)
    begin
        if (armed) begin
            trigger_buf <= i_trigger;
            trigger <= trigger_buf;
        end else begin
            trigger_buf <= 0;
            trigger <= 0;
        end
    end

    always @ (posedge clk)
    begin
        if (armed) begin
            if (trigger) go <= 1;
        end else begin
            go <= 0;
        end
    end
`else
    /* trigger on RISING edge of Nth pulse */
    parameter pulse_target = 23;

    always @ (posedge clk)
    begin
        if (armed) begin
            trigger_buf <= i_trigger;
            trigger <= trigger_buf;
            trigger_prev <= trigger;

            if (trigger && !trigger_prev) pulse_ctr <= pulse_ctr + 12'd1;
        end else begin
            pulse_ctr <= 0;
            trigger_buf <= 0;
            trigger <= 0;
            trigger_prev <= 0;
        end
    end

    always @ (posedge clk)
    begin
        if (armed) begin
            if ((go == 0) && (pulse_ctr == pulse_target)) begin
                go <= 1;
            end
        end else begin
            go <= 0;
        end
    end
`endif

    always @ (posedge clk)
    begin
        if (go) begin
            if (state == STATE_HOLDOFF) begin
                out <= { on_state, on_state };
                /* reset controlled by glitch3r */
                // rst <= rst_on_state;

                if (counter == holdoff) begin
                    counter <= 32'd0;
                    state <= STATE_GLITCH;
                end else begin
                    counter <= counter + 32'd1;
                end
            end else if (state == STATE_GLITCH) begin
                /* reset for debugging */
                rst <= rst_on_state;
                if (pattern_ctr == 6'd32) begin
                    pattern_ctr <= 6'd0;
                    out <= { on_state, on_state };
                    state <= STATE_DONE;
                end else begin
                    pattern_ctr <= pattern_ctr + 6'd1;
                    out <= { pulse[pattern_ctr * 7'd2], pulse[pattern_ctr * 7'd2 + 7'd1] };
                end
            end else begin
                rdy <= 1'b1;
                out <= { on_state, on_state };
            end
        end else begin
            state <= STATE_HOLDOFF;
            pattern_ctr <= 6'd0;
            counter <= 32'd0;
            out <= { idle_state, idle_state }; // default = 0
            rst <= ~rst_on_state;
            rdy <= 1'b0;
        end
    end
endmodule

module glitch_pulse (
    input wire clk,
    input wire armed,
    input wire idle_state,
    input wire on_state,
    input wire rst_on_state,
    input wire [31:0] holdoff,
    input wire [31:0] pulse,

    output reg [0:1] out,
    output reg rst,
    output reg rdy
    );

    parameter STATE_HOLDOFF = 2'b00;
    parameter STATE_GLITCH  = 2'b01;
    parameter STATE_DONE    = 2'b10;

    reg [31:0] counter;
    reg [31:0] pulse_ctr;
    reg [1:0] state;
    reg final_state;

    always @ (posedge clk)
    begin
        if (armed == 1'b1) begin
            if (state == STATE_HOLDOFF) begin
                out <= { on_state, on_state };
                rst <= rst_on_state;

                if (counter == holdoff) begin
                    counter <= 32'd0;
                    state <= STATE_GLITCH;
                end else begin
                    counter <= counter + 32'd1;
                end
            end else if (state == STATE_GLITCH) begin
                if (pulse_ctr >= pulse - 1) begin
                    out <= { final_state, 1 };
                    pulse_ctr <= 32'd0;
                    state <= STATE_DONE;
                end else begin
                    out <= { 0, 0 };
                    pulse_ctr <= pulse_ctr + 32'd2;
                end
            end else begin
                rdy <= 1'b1;
                out <= { 1, 1 };
            end
        end else begin
            state <= STATE_HOLDOFF;
            final_state <= (pulse[0] == 1'b1) ? 0 : 1;
            counter <= 32'd0;
            pulse_ctr <= 32'd0;
            out <= { idle_state, idle_state }; // default = 0
            rst <= ~rst_on_state;
            rdy <= 1'b0;
        end
    end
endmodule

