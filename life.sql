CREATE SCHEMA IF NOT EXISTS life;
SET search_path = life;

CREATE TABLE IF NOT EXISTS life.state (
  generation SERIAL PRIMARY KEY NOT NULL,
  --size       INT             NOT NULL CHECK (size >= 3),
  state      BOOL []
);

CREATE OR REPLACE FUNCTION life.neighbor_alive_count(u BOOL [], x INT, y INT)
  RETURNS INT AS $$
DECLARE
  ac INT := 0;
BEGIN
  FOR xo IN -1..1 LOOP
    FOR yo IN -1..1 LOOP
      IF xo = 0 AND yo = 0
      THEN
        -- dont count ourselves as a neighbor
        CONTINUE;
      END IF;
      -- we get off easy here, going out of bounds returns <NULL>
      IF u [x + xo] [y + yo]
      THEN
        ac := ac + 1;
      END IF;
    END LOOP;
  END LOOP;

  RETURN ac;
END;
$$ LANGUAGE plpgsql IMMUTABLE STRICT;

CREATE OR REPLACE FUNCTION life.next_cell_state(cur BOOL, alive_nb INT)
  RETURNS BOOL AS $$
BEGIN
  RETURN (NOT cur AND alive_nb = 3) OR alive_nb = 2 OR alive_nb = 3;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION life.next_universe(cur_uv BOOL [])
  RETURNS BOOL [] AS $$
DECLARE
  xl     INT := array_length(cur_uv, 1);
  yl     INT := array_length(cur_uv, 2);
  new_uv BOOL [] := array_fill(FALSE, ARRAY [xl, yl]);
BEGIN
  FOR x IN 1..xl LOOP
    FOR y IN 1..yl LOOP
      new_uv [x] [y] = life.next_cell_state(cur_uv [x] [y], life.neighbor_alive_count(cur_uv, x, y));
    END LOOP;
  END LOOP;
  RETURN new_uv;
END;
$$ LANGUAGE plpgsql IMMUTABLE STRICT;

CREATE OR REPLACE FUNCTION life.create_universe(size INT, fillrandom BOOL)
  RETURNS BOOL [] AS $$
DECLARE
  ret BOOL [] := NULL;
BEGIN
  ret = array_fill(FALSE, ARRAY [size, size]);
  IF fillrandom
  THEN
    FOR x IN 1..size LOOP
      FOR y IN 1..size LOOP
        ret [x] [y] = (random() * 100) :: INT % 2 = 0;
      END LOOP;
    END LOOP;
  END IF;
  RETURN ret;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION life.print_state(state BOOL [])
  RETURNS VOID AS $$
DECLARE
  line TEXT := '';
BEGIN
  FOR x IN 1..array_length(state, 1) LOOP
    FOR y IN 1..array_length(state, 2) LOOP
      IF state [x] [y]
      THEN
        line := concat(line, 'X ');
      ELSE
        line := concat(line, '  ');
      END IF;
    END LOOP;
    RAISE NOTICE '%', line;
    line := '';
  END LOOP;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE VIEW life.most_recent_state AS
  SELECT s.state
  FROM life.state s
  ORDER BY s.generation DESC
  LIMIT 1;

CREATE OR REPLACE FUNCTION life.game_of_life(boardsize INT)
  RETURNS VOID AS $$
BEGIN

  IF NOT exists(SELECT 1
                FROM life.most_recent_state)
  THEN
    INSERT INTO life.state (state) SELECT life.create_universe(boardsize, TRUE);
  ELSE
    INSERT INTO life.state (state) SELECT life.next_universe((SELECT *
                                                              FROM life.most_recent_state));
  END IF;

  PERFORM life.print_state(boardsize, (SELECT *
                                       FROM life.most_recent_state));
END;
$$ LANGUAGE plpgsql;


--SELECT life.game_of_life(6);
