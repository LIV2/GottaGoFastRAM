/*
GottaGoFastRAM - 8MB Autoconfig FastRAM for Amiga 500(+)/1000/2000/CDTV
Copyright 2020 Matthew Harlum

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

Inspired by mkl's mem68k
*/

// Config defines
`define autoconfig  // If disabled RAM is always mapped to $200000-9FFFFF
//`define cdtv      // Uncomment to build CDTV compatible version
`define rev_b

module gottagofast(
    input CLK,
    input RESETn,
    input CFGINn,
    input UDSn,
    input LDSn,
    input ASn,
    input RWn,
    inout [15:12] DBUS,
    input [23:1] ADDR,
    output reg [11:0] MADDR,
    output reg CFGOUTn,
    output RASn,
    output UCASn,
    output LCASn,
    output OEn,
    output MEMWn
    );

reg reset_delayed1;
reg reset;

// Memory controller

reg ram_cycle;
reg access_ras;
reg access_ucas;
reg access_lcas;
reg refresh_ras;
reg refresh_cas;
reg [7:0] addr_match;

`ifdef autoconfig
// Autoconfig
localparam [15:0] mfg_id  = 16'h07DB;
localparam [7:0]  prod_id = 8'd59;
localparam [15:0] serial  = 16'd421;

wire autoconfig_cycle;
reg shutup = 0;
reg CFGINnr;
reg configured;
reg [2:0] autoconfig_state;
reg [3:0] data_out;

localparam Offer_Block1 = 3'b000,
           Offer_Block2 = 3'b001,
           Offer_Block3 = 3'b010,
           Offer_Block4 = 3'b011,
           SHUTUP       = 3'b100;

assign DBUS[15:12] = (RESETn & autoconfig_cycle & RWn & !ASn & !UDSn) ? data_out[3:0] : 'bZ;

`ifdef cdtv
reg cdtv_configured;

assign autoconfig_cycle = (ADDR[23:16] == 8'hE8) & !CFGINnr & !shutup & cdtv_configured;
`else
assign autoconfig_cycle = (ADDR[23:16] == 8'hE8) & !CFGINnr & !shutup;
`endif

`ifdef cdtv
// CDTV DMAC is first in chain.
// So we wait until it's configured before we talk
always @(negedge UDSn or negedge reset)
begin
    if (!reset) begin
      cdtv_configured <= 1'b0;
    end else begin
    if (ADDR[23:16] == 8'hE8 & ADDR[8:1] == 8'h24 & !ASn & !RWn) begin
      cdtv_configured <= 1'b1;
    end
  end
end
`endif

// Register Config in/out at end of bus cycle
always @(posedge ASn or negedge reset)
begin
  if (!reset) begin
    CFGOUTn <= 1'b1;
    CFGINnr <= 1'b1;
  end else begin
    CFGOUTn <= !shutup;
    CFGINnr <= CFGINn;
  end
end

// Offer up to 8MB in 2MB Blocks
always @(posedge CLK or negedge reset)
begin
  if (!reset) begin
    data_out <= 'bZ;
  end else if (autoconfig_cycle & RWn) begin
    case (ADDR[8:1])     
      8'h00:   data_out <= (autoconfig_state == SHUTUP) ? 4'b1100 : 4'b1110; // Were we told to shut up last time?
      8'h01:   data_out <= (autoconfig_state == SHUTUP) ? 4'b0001 : 4'b0110; // If so, offer a 64kb memory block not linked to free list to fix yellow screen
      8'h02:   data_out <= ~prod_id[7:4]; // Product number
      8'h03:   data_out <= ~prod_id[3:0]; // Product number
      8'h04:   data_out <= ~4'b1000;
      8'h05:   data_out <= ~4'b0000;
      8'h08:   data_out <= ~mfg_id[15:12]; // Manufacturer ID
      8'h09:   data_out <= ~mfg_id[11:8];  // Manufacturer ID
      8'h0A:   data_out <= ~mfg_id[7:4];   // Manufacturer ID
      8'h0B:   data_out <= ~mfg_id[3:0];   // Manufacturer ID
      8'h10:   data_out <= ~serial[15:12]; // Serial number
      8'h11:   data_out <= ~serial[11:8];  // Serial number
      8'h12:   data_out <= ~serial[7:4];   // Serial number
      8'h13:   data_out <= ~serial[3:0];   // Serial number
      8'h20:   data_out <= 4'b0;
      8'h21:   data_out <= 4'b0;
      default: data_out <= 4'hF;
    endcase
  end
end

always @(negedge UDSn or negedge reset)
begin
  if (!reset) begin
    configured       <= 1'b0;
    shutup           <= 1'b0;
    addr_match       <= 8'b00000000;
    autoconfig_state <= Offer_Block1;
  end else if (autoconfig_cycle & !ASn & !RWn) begin
    if (ADDR[8:1] == 8'h26) begin
      // Shutup register
      if (autoconfig_state == SHUTUP) begin
        shutup <= 1;
      end else begin
        autoconfig_state <= SHUTUP; // Goto the bug fix cycle
      end
    end
    else if (ADDR[8:1] == 8'h24) begin
      // Configure Register
      begin
        case(DBUS)
          4'h2:    addr_match <= (addr_match|8'b00000011);
          4'h4:    addr_match <= (addr_match|8'b00001100);
          4'h6:    addr_match <= (addr_match|8'b00110000);
          4'h8:    addr_match <= (addr_match|8'b11000000);
        endcase
        if (autoconfig_state < Offer_Block4) begin
          autoconfig_state <= autoconfig_state + 1;
        end else begin
          shutup <= 1;
        end
      end
      configured <= 1'b1;
    end
  end
end
`endif

// Memory controller

assign RASn  = !(access_ras | (refresh_ras & refresh_cas));
assign UCASn = !((access_ucas) | refresh_cas);
assign LCASn = !((access_lcas) | refresh_cas);
`ifdef rev_b  // On Rev B OEn drives the buffers
assign OEn   = !ram_cycle | ASn | !RESETn | (UDSn & LDSn);
`else
assign OEn   = !(RWn & access_ras);
`endif
assign MEMWn = RWn | (UDSn & LDSn);

// Filter reset line by registering it
always @(posedge CLK)
begin
  reset_delayed1 <= RESETn;
  reset <= reset_delayed1;
end

// CAS before RAS refresh
// CAS Asserted in S1 & S2
// RAS Asserted in S2
always @(negedge CLK or negedge reset)
begin
  if (!reset) begin
    refresh_cas <= 1'b0;
  end else begin
    refresh_cas <= (!refresh_cas & ASn & !access_ras);
  end
end

always @(posedge CLK or negedge reset)
begin
  if (!reset) begin
    refresh_ras <= 1'b0;
  end else begin
    refresh_ras <= refresh_cas;
  end
end

// Memory access
always @(negedge CLK or negedge reset)
begin
  if (!reset) begin
    ram_cycle = 1'b0;
  end else begin
`ifdef autoconfig
    ram_cycle = (
      ((ADDR[23:20] == 4'h2) & addr_match[0]) |
      ((ADDR[23:20] == 4'h3) & addr_match[1]) |
      ((ADDR[23:20] == 4'h4) & addr_match[2]) |
      ((ADDR[23:20] == 4'h5) & addr_match[3]) |
      ((ADDR[23:20] == 4'h6) & addr_match[4]) |
      ((ADDR[23:20] == 4'h7) & addr_match[5]) |
      ((ADDR[23:20] == 4'h8) & addr_match[6]) |
      ((ADDR[23:20] == 4'h9) & addr_match[7])
      ) & !ASn & configured;
`else
    ram_cycle = ((ADDR[23:20] >= 4'h2) & (ADDR[23:20] <= 4'h9) & !ASn);
`endif
  end
end

always @(posedge CLK or negedge reset)
begin
  if (!reset) begin
    access_ras  <= 1'b0;
    access_ucas <= 1'b0;
    access_lcas <= 1'b0;
  end else begin
    access_ras  <= (ram_cycle & !access_ucas & !access_lcas); // Assert @ S4, Deassert @ S0
    access_ucas <= (access_ras & !access_ucas & !UDSn);       // Assert @ S6, Deassert @ S0
    access_lcas <= (access_ras & !access_lcas & !LDSn);       // Assert @ S6, Deassert @ S0
  end
end

// Row/Col mux
// Switch to ROW address at falling edge of S0
// Switch to column address at falling edge of S4
always @(negedge CLK)
begin
  if (!access_ras) begin
    MADDR[11:0]  <= ADDR[22:11]; // Row Address
  end else begin
    MADDR[11:10] <= 2'b00;
    MADDR[9:0]   <= ADDR[10:1];  // Column Address
  end
end

endmodule
