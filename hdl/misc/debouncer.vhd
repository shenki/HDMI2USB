--  Copyright (c) 2014 Timvideos Project
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

library IEEE;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity debouncer is
  port (
    clk    : in  std_logic;
    rst_n  : in  std_logic;
    insig  : in  std_logic;
    outsig : out std_logic
    );
end entity debouncer;

architecture rtl of debouncer is

  signal input_q : std_logic_vector(7 downto 0);

begin

  process(rst_n, clk)
  begin
    if rst_n = '0' then
      input_q <= (others => '0');
      outsig  <= '0';
    elsif rising_edge(clk) then
      input_q <= (input_q(6 downto 0) & insig);
      if input_q = "11111111" then
        outsig <= '1';
      elsif input_q = "00000000" then
        outsig <= '0';
      end if;
    end if;
  end process;

end architecture;
