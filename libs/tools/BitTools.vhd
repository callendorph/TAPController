library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package BitTools is

constant BYTE_WIDTH : integer := 8;
subtype BYTE_t is std_logic_vector(BYTE_WIDTH-1 downto 0);

function Log2( input:integer ) return integer;

function to_slv(val : integer; len : integer) return std_logic_vector;

function to_std_logic(x: BOOLEAN) return std_logic;

-- Make a left aligned width-bit mask. The
--   returned std_logic_vector is `len` bits long.
function make_left_mask(width : integer; len : integer) return std_logic_vector;

end package;

package body BitTools is

------------------------------------------------------
-- Compute the ceil(log2(x)) of the passed value. This is
--  useful for computing the number of bits required to
--  contain a particular value.
------------------------------------------------------
function Log2( input:integer ) return integer is
	variable temp,log:integer;
begin
	temp:=input;
	log:=0;
	while (temp /= 0) loop
		temp:=temp/2;
		log:=log+1;
	end loop;
	return log;
end function Log2;

function to_slv(val : integer; len : integer) return std_logic_vector is
begin
	return std_logic_vector(to_unsigned(val, len));
end to_slv;

function to_std_logic(x: BOOLEAN) return std_logic is
begin
  if x then
    return '1';
  else
    return '0';
  end if;
end to_std_logic;

function make_left_mask(
  width : integer; len : integer
  ) return std_logic_vector
is
  variable mask : std_logic_vector(len-1 downto 0);
begin
  mask := (others => '0');

  for m in 0 to width-1 loop
    mask := mask or to_slv( 2**m, len);
  end loop;
  mask := mask(width-1 downto 0) & to_slv(0, len-width);
  return mask;
end make_left_mask;




end BitTools;
