library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package BitTools is

constant BYTE_WIDTH : integer := 8;
subtype BYTE_t is std_logic_vector(BYTE_WIDTH-1 downto 0);

function Log2( input:integer ) return integer;
function to_string (a: std_logic_vector) return string;
function to_onehot(bit : integer; len : integer) return std_logic_vector;
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

------------------------------------------------------
-- Convert a std_logic_vector to a string. This is primarily
-- useful for test bench reporting.
------------------------------------------------------
function to_string (a: std_logic_vector) return string is
	variable b : string (1 to a'length) := (others => NUL);
	variable stri : integer := 1;
	variable s : string( 3 downto 1 );
begin
	for i in a'range loop
		s := std_logic'image(a(i));
		b(stri) := s(2);
		stri := stri+1;
	end loop;
	return b;
end function;

------------------------------------------------------
-- Similar to the `to_unsigned` method, but this converts
--  a bit to a bitmap in 'one-hot' encoding format.
--  to_onehot( 3, 8) =>  "00001000"
--  to_onehot( 2, 6) =>  "000100"
--  to_onehot( 0, 6) =>  "000001"
------------------------------------------------------
function to_onehot(bit : integer; len : integer) return std_logic_vector is
    variable result     : std_logic_vector(len - 1 downto 0);
begin
    result  := (others => '0');
    result(bit) := '1';
    return result;
end function;

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
