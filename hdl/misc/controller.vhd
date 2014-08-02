--  Copyright (c) 2013 Jahanzeb Ahmad
--
--  Redistribution and use in source and binary forms, with or without modification,
--  are permitted provided that the following conditions are met:
--
--   * Redistributions of source code must retain the above copyright notice,
--     this list of conditions and the following disclaimer.
--   * Redistributions in binary form must reproduce the above copyright notice,
--     this list of conditions and the following disclaimer in the documentation and/or
--     other materials provided with the distribution.
--
--  http://opensource.org/licenses/MIT

-- Adds
-- U = usb/uvc
-- J = jpeg encoder
-- S = source selector
-- H = Hdmi

library IEEE;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity controller is
  port
    (
      status           : out std_logic_vector(4 downto 0);
      usb_cmd          : out std_logic_vector(2 downto 0);  -- UVCpayloadheader(0),  raw/jpeg(1), uvc on/off(2)
      jpeg_encoder_cmd : out std_logic_vector(1 downto 0);  -- encodingQuality(1 downto 0)
      selector_cmd     : out std_logic_vector(12 downto 0);  -- (1:0 source ) (2 gray/color) (3 inverted/not-inverted) (4:5 blue depth) (6:7 green depth) (8:9 red depth) (10 blue on/off) (11 green on/off) (12 red on/off)
      HB_on            : out std_logic;
      hdmi_cmd         : out std_logic_vector(1 downto 0);  -- if 1 then dvi else hdmi
      hdmi_dvi         : in  std_logic_vector(1 downto 0);  -- if 1 then dvi else hdmi
      rdy_H            : in  std_logic_vector(1 downto 0);
      btnu             : in  std_logic;
      btnd             : in  std_logic;
      btnl             : in  std_logic;
      btnr             : in  std_logic;
      uvc_rst          : out std_logic;
      cmd_byte         : in  std_logic_vector(7 downto 0);
      cmd_en           : in  std_logic;
      rst              : in  std_logic;
      ifclk            : in  std_logic;
      clk              : in  std_logic
      );
end entity;

architecture rtl of controller is

  component cmdfifo
    port (
      rst          : in  std_logic;
      wr_clk       : in  std_logic;
      rd_clk       : in  std_logic;
      din          : in  std_logic_vector(7 downto 0);
      wr_en        : in  std_logic;
      rd_en        : in  std_logic;
      dout         : out std_logic_vector(15 downto 0);
      full         : out std_logic;
      almost_full  : out std_logic;
      empty        : out std_logic;
      almost_empty : out std_logic;
      valid        : out std_logic
      );
  end component;

  signal usb_cmd_i          : std_logic_vector(2 downto 0);  -- UVCpayloadheader(0),  raw/jpeg(1), uvc on/off(2)
  signal jpeg_encoder_cmd_i : std_logic_vector(1 downto 0);  -- encodingQuality(1 downto 0)
  signal selector_cmd_i     : std_logic_vector(12 downto 0);  -- (1:0 source ) (2 gray/color) (3 inverted/not-inverted) (4:5 blue depth) (6:7 green depth) (8:9 red depth) (10 blue on/off) (11 green on/off) (12 red on/off)
  signal HB_on_i            : std_logic;
  signal hdmi_cmd_i         : std_logic_vector(1 downto 0);  -- if 1 then dvi else hdmi
  signal hdmi_dvi_q         : std_logic_vector(1 downto 0);  -- if 1 then dvi else hdmi

  signal counter : std_logic_vector(7 downto 0);

  signal cmd : std_logic_vector(7 downto 0);
  signal add : std_logic_vector(7 downto 0);

  signal rd_en             : std_logic;
  signal dout              : std_logic_vector(15 downto 0);
  signal full              : std_logic;
  signal almost_full       : std_logic;
  signal empty             : std_logic;
  signal almost_empty      : std_logic;
  signal valid             : std_logic;
  signal uvc_rst_i         : std_logic;
  signal vsync_q           : std_logic;
  signal vsync_rising_edge : std_logic;
  signal pressed           : std_logic;
  signal toggle            : std_logic;


begin

-- comb logic
  usb_cmd          <= usb_cmd_i;
  jpeg_encoder_cmd <= jpeg_encoder_cmd_i;
  selector_cmd     <= selector_cmd_i;
  hdmi_cmd         <= hdmi_cmd_i;
  HB_on            <= HB_on_i;

-- CMD Decoder
  process(rst, clk)
  begin
    if rst = '1' then

      usb_cmd_i                   <= "001";  --   uvc on/off(2) raw/jpeg(1) UVCpayloadheader(0)
      jpeg_encoder_cmd_i          <= "00";   -- encodingQuality(1 downto 0)
      selector_cmd_i(3 downto 0)  <= "0111";  -- (1:0 source ) (2 gray/color) (3 inverted/not-inverted)
      selector_cmd_i(12 downto 4) <= "111000000";  --(4:5 blue depth) (6:7 green depth) (8:9 red depth) (10 blue on/off) (11 green on/off) (12 red on/off)
      HB_on_i                     <= '1';
      hdmi_cmd_i                  <= "11";   -- if 1 then dvi else hdmi
      uvc_rst_i                   <= '1';
      pressed                     <= '0';
      hdmi_dvi_q                  <= "00";
      status                      <= (others => '0');
      toggle                      <= '0';
      counter                     <= (others => '0');

    elsif rising_edge(clk) then

      if uvc_rst_i = '1' then
        uvc_rst <= '1';
        counter <= (others => '0');
        toggle  <= '1';
      else
        counter <= counter+1;
      end if;

      if counter = (counter'range => '1') and toggle = '1' then
        uvc_rst <= '0';
        toggle  <= '0';
      end if;

      uvc_rst_i  <= '0';
      status     <= (others => '0');
      rd_en      <= '0';
      hdmi_dvi_q <= hdmi_dvi;

      if (hdmi_dvi_q(0) xor hdmi_dvi(0)) = '1' then
        hdmi_cmd_i(0) <= hdmi_dvi(0);
      end if;

      if (hdmi_dvi_q(1) xor hdmi_dvi(1)) = '1' then
        hdmi_cmd_i(1) <= hdmi_dvi(1);
      end if;

      if btnd = '1' and pressed = '0' then
        uvc_rst_i                  <= '1';
        selector_cmd_i(1 downto 0) <= "11";
        pressed                    <= '1';
      else
        pressed <= '0';
      end if;

      if btnl = '1' and pressed = '0' and rdy_H(1) = '1' then
        uvc_rst_i                  <= '1';
        selector_cmd_i(1 downto 0) <= "01";
        pressed                    <= '1';
      else
        pressed <= '0';
      end if;

      if btnu = '1' and pressed = '0' and rdy_H(0) = '1' then
        uvc_rst_i                  <= '1';
        selector_cmd_i(1 downto 0) <= "00";
        pressed                    <= '1';
      else
        pressed <= '0';
      end if;

      if empty = '0' and rd_en = '0' then
        rd_en <= '1';
        case add is
          when X"55" | X"75" =>  -- U UVC/USB / UVCpayloadheader(0),  raw/jpeg(1), uvc on/off(2)
            case cmd is
              when X"4a" | X"6a" =>     -- J j
                usb_cmd_i(1) <= '1';
                uvc_rst_i    <= '1';
              when X"52" | X"72" =>     -- Rr
                usb_cmd_i(1) <= '0';
                uvc_rst_i    <= '1';
              when X"4e" | X"6e" =>     -- N n (on)
                usb_cmd_i(2) <= '1';
                uvc_rst_i    <= '1';
              when X"46" | X"66" =>     -- Ff (off)
                usb_cmd_i(2) <= '0';
                uvc_rst_i    <= '1';
              when X"56" | X"76" =>     -- V v (video) header on
                usb_cmd_i(0) <= '1';
                uvc_rst_i    <= '1';
              when X"49" | X"69" =>     -- I i (image) header off
                usb_cmd_i(0) <= '0';
                uvc_rst_i    <= '1';
              when X"53" | X"73" =>     -- Status
                status(0) <= '1';
              when X"48" | X"68" =>     -- H
                uvc_rst_i <= '1';
                if (selector_cmd_i(1 downto 0) = "00") then     -- hdmi 0
                  hdmi_cmd_i(0) <= '0';                         -- HDMI
                elsif (selector_cmd_i(1 downto 0) = "01") then  -- hdmi 1
                  hdmi_cmd_i(1) <= '0';                         -- HDMI
                end if;
              when X"44" | X"64" =>                             -- D
                uvc_rst_i <= '1';
                if (selector_cmd_i(1 downto 0) = "00") then     -- hdmi 0
                  hdmi_cmd_i(0) <= '1';                         -- DVI
                elsif (selector_cmd_i(1 downto 0) = "01") then  -- hdmi 1
                  hdmi_cmd_i(1) <= '1';                         -- DVI
                end if;

              when others =>
            end case;

          when X"4a" | X"6a" =>         -- J Jpeg
            case cmd is
              when X"53" | X"73" =>     -- Status
                status(1) <= '1';
              when X"30" =>             -- quality 100 %
                jpeg_encoder_cmd_i(1 downto 0) <= "00";
              when X"31" =>             -- quality 85%
                jpeg_encoder_cmd_i(1 downto 0) <= "01";
              when X"32" =>             -- quality 75%
                jpeg_encoder_cmd_i(1 downto 0) <= "10";
              when X"33" =>             -- quality 50%
                jpeg_encoder_cmd_i(1 downto 0) <= "11";
              when others =>
            end case;

          when X"48" | X"68" =>         -- H Hdmi
            case cmd is
              when X"53" | X"73" =>     -- Status
                status(3) <= '1';
              when X"30" =>             -- Force HDMI 0 to 720p
                hdmi_cmd_i(0) <= '0';
                uvc_rst_i     <= '1';
              when X"31" =>             -- Force HDMI 0 to 1024
                hdmi_cmd_i(0) <= '1';
                uvc_rst_i     <= '1';
              when X"32" =>             -- Force HDMI 1 to 720p
                hdmi_cmd_i(1) <= '0';
                uvc_rst_i     <= '1';
              when X"33" =>             -- Force HDMI 1 to 1024
                hdmi_cmd_i(0) <= '1';
                uvc_rst_i     <= '1';
              when others =>
            end case;

          when X"53" | X"73" =>         -- S Source Selector
            case cmd is  -- (1:0 source ) (2 gray/color) (3 inverted/not-inverted) (4:5 blue depth) (6:7 green depth) (8:9 red depth) (10 blue on/off) (11 green on/off) (12 red on/off)
              when X"53" | X"73" =>     -- Status
                status(2) <= '1';
              when X"55" | X"75" =>     -- U button force source to HDMI0
                if rdy_H(0) = '1' then
                  selector_cmd_i(1 downto 0) <= "00";
                  uvc_rst_i                  <= '1';
                end if;
              when X"4c" | X"6c" =>     -- L button force source to HDMI1
                if rdy_H(1) = '1' then
                  selector_cmd_i(1 downto 0) <= "01";
                  uvc_rst_i                  <= '1';
                end if;
              when X"52" | X"72" =>     -- V button force source to VGA
                                        -- selector_cmd_i(1 downto 0) <= "10";
              when X"44" | X"64" =>  -- D button force source to test pattern
                selector_cmd_i(1 downto 0) <= "11";
                uvc_rst_i                  <= '1';
              when X"47" | X"67" =>     -- Froce Gray
                selector_cmd_i(2) <= '0';
              when X"43" | X"63" =>     -- Froce Color
                selector_cmd_i(2) <= '1';
              when X"49" | X"69" =>  -- Invert Color
                selector_cmd_i(3) <= not selector_cmd_i(3);
              when X"48" | X"68" =>     -- Heart Beat On/Off
                HB_on_i <= not HB_on_i;
              when others =>
            end case;

          -- RGB (4:5 blue depth) (6:7 green depth) (8:9 red depth) (10 blue on/off) (11 green on/off) (12 red on/off)
          when X"52" | X"72" =>         -- Red
            case cmd is
              when X"4e" | X"6e" =>     -- N n (on)
                selector_cmd_i(12) <= '1';
              when X"46" | X"66" =>     -- Ff (off)
                selector_cmd_i(12) <= '0';
              when X"30" =>
                selector_cmd_i(9 downto 8) <= "00";
              when X"31" =>
                selector_cmd_i(9 downto 8) <= "01";
              when X"32" =>
                selector_cmd_i(9 downto 8) <= "10";
              when X"33" =>
                selector_cmd_i(9 downto 8) <= "11";
              when others =>
            end case;
          when X"47" | X"67" =>  -- Green (4:5 blue depth) (6:7 green depth) (8:9 red depth) (10 blue on/off) (11 green on/off) (12 red on/off)
            case cmd is
              when X"4e" | X"6e" =>     -- N n (on)
                selector_cmd_i(11) <= '1';
              when X"46" | X"66" =>     -- Ff (off)
                selector_cmd_i(11) <= '0';
              when X"30" =>
                selector_cmd_i(7 downto 6) <= "00";
              when X"31" =>
                selector_cmd_i(7 downto 6) <= "01";
              when X"32" =>
                selector_cmd_i(7 downto 6) <= "10";
              when X"33" =>
                selector_cmd_i(7 downto 6) <= "11";
              when others =>
            end case;
          when X"42" | X"62" =>         -- Blue
            case cmd is
              when X"4e" | X"6e" =>     -- N n (on)
                selector_cmd_i(10) <= '1';
              when X"46" | X"66" =>     -- Ff (off)
                selector_cmd_i(10) <= '0';
              when X"30" =>
                selector_cmd_i(5 downto 4) <= "00";
              when X"31" =>
                selector_cmd_i(5 downto 4) <= "01";
              when X"32" =>
                selector_cmd_i(5 downto 4) <= "10";
              when X"33" =>
                selector_cmd_i(5 downto 4) <= "11";
              when others =>
            end case;
          when X"44" | X"64" =>         --Debug
            case cmd is
              when X"53" | X"73" =>     --Status
                status(4) <= '1';
              when others =>
            end case;

          when others =>
        end case;  -- case add
      end if;  -- cmd_en
    end if;  -- clk
  end process;

  cmd <= dout(7 downto 0);
  add <= dout(15 downto 8);

  cmdfifo_comp : cmdfifo
    port map (
      rst          => rst,
      wr_clk       => ifclk,
      rd_clk       => clk,
      din          => cmd_byte,
      wr_en        => cmd_en,
      rd_en        => rd_en,
      dout         => dout,
      full         => full,
      almost_full  => almost_full,
      empty        => empty,
      almost_empty => almost_empty,
      valid        => valid
      );

end architecture;
