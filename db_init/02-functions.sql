-- Custom application functions
-- This ensures the get_last_name function exists regardless of how data is restored

CREATE OR REPLACE FUNCTION get_last_name(full_name text) RETURNS text AS $$
BEGIN
  IF position(',' in full_name) > 0 THEN
    RETURN trim(split_part(full_name, ',', 1));
  ELSE
    RETURN (string_to_array(trim(full_name), ' '))[array_upper(string_to_array(trim(full_name), ' '), 1)];
  END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE;