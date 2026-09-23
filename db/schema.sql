--
-- PostgreSQL database dump
--

\restrict wS0KYLIV3qXhIpdZ7DQYT14hl5PRGCja1MPuAwkkkCBcZBJA0UzerlLa1dcA3NZ

-- Dumped from database version 16.15 (Ubuntu 16.15-0ubuntu0.24.04.1)
-- Dumped by pg_dump version 16.15 (Ubuntu 16.15-0ubuntu0.24.04.1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: accessibility_rank(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.accessibility_rank(raw text) RETURNS numeric
    LANGUAGE sql IMMUTABLE
    AS $$
    WITH base AS (
        -- Drop the parenthetical caveat; it is commentary, not difficulty.
        SELECT trim(regexp_replace(lower(coalesce(raw, '')), '\([^)]*\)', '', 'g')) AS b
    )
    SELECT CASE
        -- Access mode or permission, not difficulty.
        WHEN b ~ '(kayak|boat|private|no access|not accessible)' THEN NULL
        ELSE (
            CASE
                -- Highest first: "very hard" must not be read as "hard", and
                -- a range like "Easy/Moderate" resolves to its harder end,
                -- which is the safer way to be wrong when someone is deciding
                -- whether to take it on.
                WHEN b ~ 'very\s+hard'              THEN 4
                WHEN b ~ '(hard|difficult)'         THEN 3
                WHEN b ~ '(moderate|medium|average)' THEN 2
                WHEN b ~ 'easy'                     THEN 1
                WHEN b ~ 'roadside'                 THEN 0
                ELSE NULL
            END
            + CASE WHEN b ~ '\+\+' THEN 1.0 WHEN b ~ '\+' THEN 0.5 ELSE 0 END
        )
    END FROM base
$$;


--
-- Name: FUNCTION accessibility_rank(raw text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.accessibility_rank(raw text) IS 'Difficulty as a number so two sources can be compared: Roadside 0 to Very Hard 4, a trailing + worth half a step. Null where the value is about permission or transport rather than difficulty. Agreement is within half a step, because the + is a hikingwnc habit other sources do not share.';


--
-- Name: agreement_note(integer, integer, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.agreement_note(agreeing integer, n integer, tolerance text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT CASE
      WHEN n <= 1 THEN 'Only one source has a value, so there is nothing to compare it with.'
      WHEN agreeing <= 1 THEN 'No two of the ' || n || ' sources agree ' || tolerance || '.'
      ELSE agreeing || ' of ' || n || ' sources agree ' || tolerance || '.'
    END;
$$;


--
-- Name: FUNCTION agreement_note(agreeing integer, n integer, tolerance text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.agreement_note(agreeing integer, n integer, tolerance text) IS 'The sentence under a fact''s grade. Counts come from a self-join that includes the row itself, so an agreeing count of 1 means nothing agreed and must not be printed as though something did.';


--
-- Name: claim_units(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.claim_units(raw text, field text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT CASE
    WHEN field IN ('height_ft', 'elevation_ft', 'elevation_gain_ft') THEN 'feet'
    -- Uniform by construction now, rather than by luck of what was written.
    WHEN field = 'hike_distance' THEN 'feet'
    WHEN field IN ('coordinate', 'parking_coordinate', 'view_coordinate',
                   'coordinate_raw') THEN 'degrees'
    WHEN field IN ('beauty_rating', 'photo_rating', 'solitude_rating') THEN 'of 10'
    ELSE NULL
  END;
$$;


--
-- Name: FUNCTION claim_units(raw text, field text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.claim_units(raw text, field text) IS 'The unit a claim''s normalized_value is in. Uniform per field, because normalizing converts to it -- the source''s own unit stays visible in the raw value.';


--
-- Name: confusion_set_entries_are_append_only(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.confusion_set_entries_are_append_only() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF TG_OP = 'DELETE'
       AND NOT EXISTS (SELECT 1 FROM confusion_sets WHERE id = OLD.confusion_set_id) THEN
        -- The set itself is being removed; the journal goes with it.
        RETURN OLD;
    END IF;
    RAISE EXCEPTION
        'confusion_set_entries is append-only: add a new entry correcting the old one';
END;
$$;


--
-- Name: height_gap(numeric, numeric); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.height_gap(a numeric, b numeric) RETURNS numeric
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT CASE
        WHEN a IS NULL OR b IS NULL OR greatest(a, b) = 0 THEN NULL
        ELSE (greatest(a, b) - least(a, b)) / greatest(a, b)
    END
$$;


--
-- Name: FUNCTION height_gap(a numeric, b numeric); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.height_gap(a numeric, b numeric) IS 'Difference between two heights as a fraction of the larger. Within 0.15, an exact reading beats an approximate one; beyond it, neither wins and the honest answer is a range.';


--
-- Name: height_is_approximate(numeric); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.height_is_approximate(feet numeric) RETURNS boolean
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT CASE
        WHEN feet IS NULL THEN NULL
        WHEN feet < 50  THEN feet::numeric % 5 = 0
        WHEN feet <= 100 THEN feet::numeric % 10 = 0 OR feet::numeric % 25 = 0
        ELSE feet::numeric % 25 = 0
    END
$$;


--
-- Name: FUNCTION height_is_approximate(feet numeric); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.height_is_approximate(feet numeric) IS 'True when a height is rounded at the granularity people use for numbers that size -- under 50 to the nearest 5, 50-100 to 10 or 25, above that to 25 -- which is the signal that it is an estimate rather than a measurement.';


--
-- Name: hike_distance_feet(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.hike_distance_feet(raw text) RETURNS numeric
    LANGUAGE plpgsql IMMUTABLE
    AS $_$
DECLARE
    t   text;
    num numeric;
    ft  numeric;
BEGIN
    t := lower(coalesce(raw, ''));

    -- An em dash is ncwaterfalls writing "we do not know", not a distance.
    IF t = '' OR t ~ '^\s*[—–-]\s*$' THEN
        RETURN NULL;
    END IF;

    -- No walk at all.
    IF t ~ 'roadside' THEN
        RETURN 0;
    END IF;

    -- First number in the string. "163 steps plus 123 yards" takes the 163,
    -- which is wrong, but it is one row and guessing which number a sentence
    -- means is worse than being predictable.
    num := nullif(substring(t from '([0-9]+(?:\.[0-9]+)?)'), '')::numeric;
    IF num IS NULL THEN
        RETURN NULL;
    END IF;

    IF t ~ 'yard' THEN
        ft := num * 3;
    ELSIF t ~ 'kilometre|kilometer|\ykm\y' THEN
        ft := num * 3280.84;
    ELSIF t ~ 'metre|meter' THEN
        ft := num * 3.28084;
    ELSIF t ~ '\yft\y|foot|feet' THEN
        ft := num;
    ELSIF t ~ '\ym\y' AND num >= 20 THEN
        -- Bare "m" with a big number is metres; a small one is miles.
        ft := num * 3.28084;
    ELSE
        ft := num * 5280;
    END IF;

    -- The column means round trip, so halve-distance phrasing doubles.
    IF t ~ 'each way|one way' THEN
        ft := ft * 2;
    END IF;

    RETURN round(ft);
END;
$_$;


--
-- Name: FUNCTION hike_distance_feet(raw text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.hike_distance_feet(raw text) IS 'Round-trip walking distance in feet, parsed out of the free text the sources write. Doubles anything marked each way or one way, since the field means round trip. Null where the value is not a distance at all.';


--
-- Name: name_core(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.name_core(raw text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $_$
  SELECT nullif(trim(regexp_replace(
    regexp_replace(
      regexp_replace(
        regexp_replace(lower(coalesce(raw, '')), '\([^)]*\)', ' ', 'g'),
        '\s*[-—–]\s*(a\.k\.a\.|hiking|photos?|maps?|guides?|directions?|history|visit(ing)?|info)\y.*$', '', ''),
      '\s+(visiting|visit|info|hiking\s+guide.*)$', '', ''),
    '[^a-z0-9 ]', ' ', 'g')), '')
$_$;


--
-- Name: FUNCTION name_core(raw text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.name_core(raw text) IS 'Reduces a source page title to the name it is actually about: drops parentheticals, the SEO tail ncwaterfalls appends, and punctuation. Used to compare a source name against ours without comparing their marketing.';


--
-- Name: name_display(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.name_display(raw text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $_$
  SELECT nullif(btrim(regexp_replace(
    regexp_replace(
      regexp_replace(
        -- "... via Summey Cove Trail" is the route, not the waterfall.
        regexp_replace(coalesce(raw, ''), '\s+via\s+.*$', '', 'i'),
        '\([^)]*\)', ' ', 'g'),
      '\s*[-—–]\s*(a\.k\.a\.|hiking|photos?|maps?|guides?|directions?|history|visit(ing)?|info)\M.*$',
      '', 'i'),
    '\s+', ' ', 'g'), ' ,;-'), '');
$_$;


--
-- Name: FUNCTION name_display(raw text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.name_display(raw text) IS 'name_core() for people rather than for matching: drops the parenthetical and the SEO tail, but keeps case and punctuation.';


--
-- Name: name_key(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.name_key(raw text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT nullif(regexp_replace(name_core(raw), '\s+', ' ', 'g'), '')
$$;


--
-- Name: name_parenthetical(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.name_parenthetical(raw text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT nullif(btrim(substring(coalesce(raw, '') from '\(([^)]*)\)')), '');
$$;


--
-- Name: normalize_claim_value(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.normalize_claim_value(raw text, field text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT normalize_claim_value(raw, field, NULL);
$$;


--
-- Name: FUNCTION normalize_claim_value(raw text, field text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.normalize_claim_value(raw text, field text) IS 'Strips hedging words, tildes and parenthetical asides, then collapses whitespace. Case is preserved: this tidies a value, it does not fold it. Names and aliases are returned null -- their parentheses disambiguate colliding waterfalls and must survive. Parentheses naming a direction survive too, because the distance parser reads them.';


--
-- Name: normalize_claim_value(text, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.normalize_claim_value(raw text, field text, source text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT CASE
    WHEN field IN ('name', 'alias') THEN name_display(raw)
    WHEN field = 'hike_distance' THEN
      (hike_distance_feet(
         coalesce(
           nullif(btrim(regexp_replace(
             regexp_replace(
               regexp_replace(
                 regexp_replace(coalesce(raw, ''),
                   '\((?![^)]*(each way|one way|out and back|round trip))[^)]*\)',
                   ' ', 'gi'),
                 '\m(approx\.?|approximately|about|around|roughly|est\.?|estimated|circa|ca\.?)\M',
                 ' ', 'gi'),
               '~', ' ', 'g'),
             '\s+', ' ', 'g'), ' .,;'), ''),
           coalesce(raw, '')))
       -- One way, so a round trip is twice. Only where the text has not
       -- already said so and had it doubled for us.
       * CASE WHEN source = 'ncwaterfalls'
                AND coalesce(raw, '') !~* 'each way|one way|out and back|round trip'
              THEN 2 ELSE 1 END)::text
    ELSE nullif(btrim(regexp_replace(
      regexp_replace(
        regexp_replace(
          regexp_replace(coalesce(raw, ''),
            '\((?![^)]*(each way|one way|out and back|round trip))[^)]*\)',
            ' ', 'gi'),
          '\m(approx\.?|approximately|about|around|roughly|est\.?|estimated|circa|ca\.?)\M',
          ' ', 'gi'),
        '~', ' ', 'g'),
      '\s+', ' ', 'g'), ' .,;'), '')
  END;
$$;


--
-- Name: FUNCTION normalize_claim_value(raw text, field text, source text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.normalize_claim_value(raw text, field text, source text) IS 'The uniform form of a claim: a display name for names, round-trip feet for distances, tidied text otherwise. Takes the source because two conventions cannot be read off the text -- AllTrails names routes, and ncwaterfalls measures one way.';


--
-- Name: parenthetical_kind(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.parenthetical_kind(inside text, field text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $_$
  SELECT CASE
    WHEN field NOT IN ('name', 'alias') THEN NULL
    WHEN inside IS NULL OR btrim(inside) = '' THEN NULL
    -- An alias is another name for the same water, so it names water.
    WHEN inside ~* '(falls|waterfall|cascade|shoals|cataract)' THEN 'alias'
    -- Provenance and status, not part of anybody's name.
    WHEN inside ~* '^(my name|name|unofficial name|private|access restricted|th|gone|closed)\M'
      OR inside ~ '^[0-9]{2}-[0-9]{2}-[0-9]{4}$' THEN 'note'
    ELSE 'disambiguator'
  END;
$_$;


--
-- Name: FUNCTION parenthetical_kind(inside text, field text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.parenthetical_kind(inside text, field text) IS 'Which of the three things a name''s parenthesis is holding: alias, disambiguator or note. Null for every other field, whose parentheses are description rather than naming. A reading, not a verdict -- see 116 for the counts it was derived from.';


--
-- Name: petzoldt_band(numeric); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.petzoldt_band(d numeric) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT CASE
        WHEN d IS NULL     THEN NULL
        WHEN d < 2.5       THEN 'easy'
        WHEN d < 5         THEN 'moderate'
        WHEN d < 7.5       THEN 'challenging'
        WHEN d < 10        THEN 'hard'
        WHEN d < 12.5      THEN 'very hard'
        ELSE                    'extreme'
    END;
$$;


--
-- Name: proto_display(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.proto_display(raw text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $_$
  SELECT nullif(btrim(regexp_replace(
    regexp_replace(
      regexp_replace(coalesce(raw,''), '\([^)]*\)', ' ', 'g'),
      '\s*[-—–]\s*(a\.k\.a\.|hiking|photos?|maps?|guides?|directions?|history|visit(ing)?|info)\M.*$', '', 'i'),
    '\s+', ' ', 'g'), ' ,;-'), '');
$_$;


--
-- Name: slugify(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.slugify(name text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT trim(both '-' from
           regexp_replace(
           regexp_replace(
           regexp_replace(lower(unaccent_fallback(name)),
             '&', ' and ', 'g'),
             '[^a-z0-9]+', '-', 'g'),
             '-{2,}', '-', 'g'));
$$;


--
-- Name: touch_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.touch_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;


--
-- Name: unaccent_fallback(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.unaccent_fallback(name text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT translate(name, E'’‘“”', '''''""');
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: areas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.areas (
    id integer NOT NULL,
    name character varying(80) NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    slug text NOT NULL,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: areas_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.areas_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: areas_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.areas_id_seq OWNED BY public.areas.id;


--
-- Name: challenges; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.challenges (
    id integer NOT NULL,
    name character varying(100) NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    target integer,
    slug text NOT NULL,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT challenges_target_positive CHECK (((target IS NULL) OR (target > 0)))
);


--
-- Name: COLUMN challenges.target; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.challenges.target IS 'Visits needed to complete. NULL = every goal on the list.';


--
-- Name: challenges_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.challenges_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: challenges_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.challenges_id_seq OWNED BY public.challenges.id;


--
-- Name: claim_groups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.claim_groups (
    id integer NOT NULL,
    ref text NOT NULL,
    feature_id integer NOT NULL,
    source character varying(30) NOT NULL,
    url text,
    observed_on date,
    identity_certain boolean DEFAULT true NOT NULL,
    note text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: claims; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.claims (
    id integer NOT NULL,
    group_id integer NOT NULL,
    feature_id integer NOT NULL,
    field character varying(24) NOT NULL,
    value jsonb NOT NULL,
    accepted boolean DEFAULT false NOT NULL,
    note text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    fact_id integer,
    normalized_value jsonb,
    parenthetical text,
    CONSTRAINT claims_field_known CHECK (((field)::text = ANY (ARRAY['coordinate'::text, 'parking_coordinate'::text, 'view_coordinate'::text, 'height_ft'::text, 'elevation_ft'::text, 'elevation_gain_ft'::text, 'petzoldt'::text, 'beauty_rating'::text, 'photo_rating'::text, 'solitude_rating'::text, 'hike_distance'::text, 'accessibility'::text, 'owner'::text, 'name'::text, 'alias'::text, 'coordinate_raw'::text, 'photos_count'::text, 'completed_hikes_count'::text, 'reviews_count'::text]))),
    CONSTRAINT claims_value_shape CHECK (
CASE
    WHEN ((field)::text = ANY (ARRAY['coordinate'::text, 'parking_coordinate'::text, 'view_coordinate'::text])) THEN ((jsonb_typeof((value -> 'lat'::text)) = 'number'::text) AND (jsonb_typeof((value -> 'lon'::text)) = 'number'::text) AND (((value ->> 'lat'::text))::numeric >= ('-90'::integer)::numeric) AND (((value ->> 'lat'::text))::numeric <= (90)::numeric) AND (((value ->> 'lon'::text))::numeric >= ('-180'::integer)::numeric) AND (((value ->> 'lon'::text))::numeric <= (180)::numeric))
    WHEN ((field)::text = 'height_ft'::text) THEN ((jsonb_typeof(value) = 'number'::text) AND (((value #>> '{}'::text[]))::numeric > (0)::numeric))
    WHEN ((field)::text = ANY (ARRAY['elevation_ft'::text, 'elevation_gain_ft'::text])) THEN (jsonb_typeof(value) = 'number'::text)
    WHEN ((field)::text = 'petzoldt'::text) THEN ((jsonb_typeof(value) = 'number'::text) AND (((value #>> '{}'::text[]))::numeric >= (0)::numeric))
    WHEN ((field)::text = ANY (ARRAY['beauty_rating'::text, 'photo_rating'::text, 'solitude_rating'::text])) THEN ((jsonb_typeof(value) = 'number'::text) AND (((value #>> '{}'::text[]))::numeric >= (1)::numeric) AND (((value #>> '{}'::text[]))::numeric <= (10)::numeric))
    WHEN ((field)::text = ANY (ARRAY['photos_count'::text, 'completed_hikes_count'::text, 'reviews_count'::text])) THEN ((jsonb_typeof(value) = 'number'::text) AND (((value #>> '{}'::text[]))::numeric >= (0)::numeric))
    ELSE ((jsonb_typeof(value) = 'string'::text) AND ((value #>> '{}'::text[]) <> ''::text))
END)
);


--
-- Name: COLUMN claims.normalized_value; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.claims.normalized_value IS 'value with hedges ("approx", "about", "~") and parenthetical asides removed. Null when value needed no tidying, so read it as coalesce(normalized_value, value).';


--
-- Name: COLUMN claims.parenthetical; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.claims.parenthetical IS 'What normalizing lifted out of value, verbatim and unclassified -- "Gorges", "Upper", "Guardrail Falls", "My name". Derived, not claimed: the raw value is still the claim. For a name, parenthetical_kind() reads it as an alias, a disambiguator or a note, but that reading is not stored yet. On other fields it is plain description.';


--
-- Name: features; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.features (
    id integer NOT NULL,
    name character varying(100) NOT NULL,
    parking_location_id integer,
    feature_location_id integer,
    visited boolean DEFAULT false,
    rt_hike_distance text,
    difficulty_rating character(1),
    beauty_rating integer,
    photo_rating integer,
    solitude_rating integer,
    hwnc_id integer,
    cmc_hike_no integer,
    book_page integer,
    kind character varying(20) DEFAULT 'waterfall'::character varying NOT NULL,
    accessibility text,
    height_ft integer,
    owner character varying(40),
    deprecated_reason character varying(24),
    deprecated_note text,
    deprecated_on date,
    elevation_ft integer,
    view_location_id integer,
    elevation_gain_ft integer,
    petzoldt numeric(5,2) GENERATED ALWAYS AS (
CASE
    WHEN ((rt_hike_distance ~ '^[0-9]+(\.[0-9]+)?$'::text) AND (elevation_gain_ft IS NOT NULL)) THEN round(((rt_hike_distance)::numeric + ((elevation_gain_ft)::numeric / 500.0)), 2)
    ELSE NULL::numeric
END) STORED,
    slug text NOT NULL,
    swimmable boolean DEFAULT false NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT features_beauty_range CHECK (((beauty_rating >= 1) AND (beauty_rating <= 10))),
    CONSTRAINT features_deprecated_note_check CHECK (((deprecated_note IS NULL) OR (deprecated_reason IS NOT NULL))),
    CONSTRAINT features_deprecated_reason_check CHECK (((deprecated_reason IS NULL) OR ((deprecated_reason)::text = ANY ((ARRAY['destroyed'::character varying, 'damaged'::character varying, 'private_property'::character varying, 'access_closed'::character varying, 'hazard'::character varying])::text[])))),
    CONSTRAINT features_difficulty_rating_check CHECK ((difficulty_rating = ANY (ARRAY['E'::bpchar, 'M'::bpchar, 'D'::bpchar]))),
    CONSTRAINT features_kind_check CHECK (((kind)::text = ANY ((ARRAY['waterfall'::character varying, 'tower'::character varying, 'vista'::character varying, 'swimming_hole'::character varying, 'other'::character varying])::text[]))),
    CONSTRAINT features_photo_range CHECK (((photo_rating >= 1) AND (photo_rating <= 10))),
    CONSTRAINT features_solitude_range CHECK (((solitude_rating >= 1) AND (solitude_rating <= 10)))
);


--
-- Name: COLUMN features.owner; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.features.owner IS 'Landowner/manager: Federal, State, GSMNP, Cherokee, Conservancy, Private, Duke Energy. Drives access expectations -- Private may charge, Conservancy may restrict hours.';


--
-- Name: COLUMN features.elevation_ft; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.features.elevation_ft IS 'Elevation of the feature itself, where a source gives one. Currently towers only.';


--
-- Name: claim_conflicts; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.claim_conflicts AS
 SELECT c.feature_id,
    f.name,
    c.field,
    count(DISTINCT c.value) AS distinct_values,
    count(*) FILTER (WHERE c.accepted) AS accepted,
    string_agg(DISTINCT (cg.source)::text, ', '::text ORDER BY (cg.source)::text) AS sources
   FROM ((public.claims c
     JOIN public.claim_groups cg ON ((cg.id = c.group_id)))
     JOIN public.features f ON ((f.id = c.feature_id)))
  WHERE ((c.field)::text <> 'alias'::text)
  GROUP BY c.feature_id, f.name, c.field
 HAVING ((count(DISTINCT c.value) > 1) OR (count(*) FILTER (WHERE c.accepted) = 0));


--
-- Name: claim_coordinate_spread; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.claim_coordinate_spread AS
 WITH pts AS (
         SELECT c.feature_id,
            cg.source,
            c.accepted,
            ((c.value ->> 'lat'::text))::numeric AS lat,
            ((c.value ->> 'lon'::text))::numeric AS lon
           FROM (public.claims c
             JOIN public.claim_groups cg ON ((cg.id = c.group_id)))
          WHERE ((c.field)::text = 'coordinate'::text)
        )
 SELECT s.feature_id,
    f.name,
    round(max(((111320)::double precision * sqrt(((power((a.lat - b.lat), (2)::numeric))::double precision + power((((a.lon - b.lon))::double precision * cos(radians((a.lat)::double precision))), (2)::double precision)))))) AS metres_apart,
    max(s.sources) AS sources,
    bool_or(s.decided) AS decided
   FROM (((( SELECT pts.feature_id,
            count(DISTINCT pts.source) AS sources,
            bool_or(pts.accepted) AS decided
           FROM pts
          GROUP BY pts.feature_id) s
     JOIN pts a ON ((a.feature_id = s.feature_id)))
     JOIN pts b ON (((b.feature_id = s.feature_id) AND ((b.source)::text > (a.source)::text))))
     JOIN public.features f ON ((f.id = s.feature_id)))
  GROUP BY s.feature_id, f.name;


--
-- Name: claim_groups_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.claim_groups_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: claim_groups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.claim_groups_id_seq OWNED BY public.claim_groups.id;


--
-- Name: claims_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.claims_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: claims_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.claims_id_seq OWNED BY public.claims.id;


--
-- Name: confusion_set_entries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.confusion_set_entries (
    id integer NOT NULL,
    confusion_set_id integer NOT NULL,
    body text NOT NULL,
    author text NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: TABLE confusion_set_entries; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.confusion_set_entries IS 'Append-only journal. A changed conclusion is a new entry, never an edit. author may be jw only when the words are his verbatim; anything an agent composed or paraphrased is authored by the agent, even when the thinking came from jw.';


--
-- Name: confusion_set_entries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.confusion_set_entries_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: confusion_set_entries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.confusion_set_entries_id_seq OWNED BY public.confusion_set_entries.id;


--
-- Name: confusion_set_members; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.confusion_set_members (
    confusion_set_id integer NOT NULL,
    feature_id integer NOT NULL
);


--
-- Name: confusion_sets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.confusion_sets (
    id integer NOT NULL,
    name text NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: TABLE confusion_sets; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.confusion_sets IS 'A named cluster of similarly-named but distinct features. Names are written by hand -- a generated "Falls Named {x}" default was considered and dropped, since most collisions here are descriptive words (Big, High, Rainbow) where it reads badly.';


--
-- Name: confusion_sets_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.confusion_sets_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: confusion_sets_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.confusion_sets_id_seq OWNED BY public.confusion_sets.id;


--
-- Name: locations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.locations (
    id integer NOT NULL,
    latitude numeric(10,8),
    longitude numeric(11,8),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: coordinate_confidence; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.coordinate_confidence AS
 WITH pts AS (
         SELECT c.feature_id,
                CASE
                    WHEN ((cg.source)::text ~~ 'hikingwnc%'::text) THEN 'hikingwnc'::character varying
                    ELSE cg.source
                END AS source,
            ((c.value ->> 'lat'::text))::numeric AS lat,
            ((c.value ->> 'lon'::text))::numeric AS lon
           FROM (public.claims c
             JOIN public.claim_groups cg ON ((cg.id = c.group_id)))
          WHERE (((c.field)::text = 'coordinate'::text) AND cg.identity_certain)
        ), stored AS (
         SELECT f.id AS feature_id,
            f.name,
            l.latitude AS lat,
            l.longitude AS lon
           FROM (public.features f
             LEFT JOIN public.locations l ON ((l.id = f.feature_location_id)))
          WHERE (f.deprecated_reason IS NULL)
        ), spread AS (
         SELECT a.feature_id,
            max(((111320)::double precision * sqrt(((power((a.lat - b.lat), (2)::numeric))::double precision + power((((a.lon - b.lon))::double precision * cos(radians((a.lat)::double precision))), (2)::double precision))))) AS metres
           FROM (pts a
             JOIN pts b ON (((b.feature_id = a.feature_id) AND ((b.source)::text > (a.source)::text))))
          GROUP BY a.feature_id
        ), nearest AS (
         SELECT p_1.feature_id,
            min(((111320)::double precision * sqrt(((power((s_1.lat - p_1.lat), (2)::numeric))::double precision + power((((s_1.lon - p_1.lon))::double precision * cos(radians((s_1.lat)::double precision))), (2)::double precision))))) AS metres
           FROM (pts p_1
             JOIN stored s_1 ON (((s_1.feature_id = p_1.feature_id) AND (s_1.lat IS NOT NULL))))
          GROUP BY p_1.feature_id
        )
 SELECT s.feature_id,
    s.name,
    count(DISTINCT p.source) AS sources,
    round(COALESCE(spread.metres, (0)::double precision)) AS sources_apart_m,
    round(nearest.metres) AS ours_off_by_m,
        CASE
            WHEN (s.lat IS NULL) THEN 'no coordinate'::text
            WHEN (count(p.source) = 0) THEN 'unsourced'::text
            WHEN (COALESCE(spread.metres, (0)::double precision) > (500)::double precision) THEN 'disputed'::text
            WHEN ((count(DISTINCT p.source) >= 3) AND (COALESCE(spread.metres, (0)::double precision) <= (100)::double precision) AND (nearest.metres <= (100)::double precision)) THEN 'confirmed'::text
            WHEN ((count(DISTINCT p.source) >= 2) AND (COALESCE(spread.metres, (0)::double precision) <= (250)::double precision) AND (nearest.metres <= (250)::double precision)) THEN 'corroborated'::text
            WHEN ((count(DISTINCT p.source) = 1) AND (nearest.metres <= (100)::double precision)) THEN 'single source'::text
            ELSE 'unverified'::text
        END AS tier
   FROM (((stored s
     LEFT JOIN pts p ON ((p.feature_id = s.feature_id)))
     LEFT JOIN spread ON ((spread.feature_id = s.feature_id)))
     LEFT JOIN nearest ON ((nearest.feature_id = s.feature_id)))
  GROUP BY s.feature_id, s.name, s.lat, spread.metres, nearest.metres;


--
-- Name: corrections; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.corrections (
    id integer NOT NULL,
    user_id integer,
    feature_id integer,
    subject text,
    field character varying(40),
    current_value text,
    suggested_value text,
    comment text,
    status character varying(20) DEFAULT 'open'::character varying NOT NULL,
    resolved_by integer,
    resolved_at timestamp without time zone,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT corrections_has_target CHECK (((feature_id IS NOT NULL) OR (subject IS NOT NULL))),
    CONSTRAINT corrections_status_check CHECK (((status)::text = ANY ((ARRAY['open'::character varying, 'accepted'::character varying, 'rejected'::character varying, 'duplicate'::character varying])::text[])))
);


--
-- Name: corrections_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.corrections_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: corrections_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.corrections_id_seq OWNED BY public.corrections.id;


--
-- Name: facts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.facts (
    id integer NOT NULL,
    feature_id integer NOT NULL,
    key text NOT NULL,
    value text,
    value_type text DEFAULT 'string'::text NOT NULL,
    units text,
    confidence_stage text DEFAULT 'single_source'::text NOT NULL,
    confidence_score numeric(2,1),
    notes text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT facts_coordinate_lat_first CHECK (((value_type <> 'coordinate'::text) OR (value IS NULL) OR ((((split_part(value, ','::text, 1))::numeric >= (30)::numeric) AND ((split_part(value, ','::text, 1))::numeric <= (40)::numeric)) AND (((split_part(value, ','::text, 2))::numeric >= ('-90'::integer)::numeric) AND ((split_part(value, ','::text, 2))::numeric <= ('-75'::integer)::numeric))))),
    CONSTRAINT facts_score_range CHECK (((confidence_score IS NULL) OR ((confidence_score >= (0)::numeric) AND (confidence_score <= 4.3)))),
    CONSTRAINT facts_stage_known CHECK ((confidence_stage = ANY (ARRAY['disputed'::text, 'single_source'::text, 'disambiguated'::text, 'corroborated'::text, 'ai_reviewed'::text, 'human_reviewed'::text, 'confirmed_irl'::text]))),
    CONSTRAINT facts_value_type_known CHECK ((value_type = ANY (ARRAY['string'::text, 'integer'::text, 'decimal'::text, 'coordinate'::text])))
);


--
-- Name: TABLE facts; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.facts IS 'What we currently think about each feature, derived from claims. A cache: rebuildable from claims at any time. Review work belongs in claims, not here.';


--
-- Name: facts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.facts_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: facts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.facts_id_seq OWNED BY public.facts.id;


--
-- Name: feature_areas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.feature_areas (
    feature_id integer NOT NULL,
    area_id integer NOT NULL,
    source character varying(20) NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: feature_notes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.feature_notes (
    id integer NOT NULL,
    feature_id integer NOT NULL,
    severity text NOT NULL,
    text text NOT NULL,
    source text NOT NULL,
    observed_on date,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT feature_notes_severity_check CHECK ((severity = ANY (ARRAY['info'::text, 'fee'::text, 'restricted'::text, 'urgent'::text, 'closed'::text])))
);


--
-- Name: TABLE feature_notes; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.feature_notes IS 'Conditions worth knowing before visiting: closures, fees, hazards, seasonal notes. severity is one of closed/restricted/fee/info. observed_on is when the condition was seen, not an expiry; surface the note and let the visitor judge currency.';


--
-- Name: feature_notes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.feature_notes_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: feature_notes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.feature_notes_id_seq OWNED BY public.feature_notes.id;


--
-- Name: feature_views; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.feature_views (
    feature_id integer NOT NULL,
    date date DEFAULT CURRENT_DATE NOT NULL,
    view_count integer DEFAULT 1 NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: TABLE feature_views; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.feature_views IS 'Daily drawer-open counts per waterfall, incremented by POST /features/:id/view. Counts events; does not identify visitors.';


--
-- Name: features_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.features_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: features_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.features_id_seq OWNED BY public.features.id;


--
-- Name: goals; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.goals (
    challenge_id integer NOT NULL,
    feature_id integer NOT NULL,
    id integer NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: goals_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.goals_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: goals_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.goals_id_seq OWNED BY public.goals.id;


--
-- Name: links; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.links (
    id integer NOT NULL,
    feature_id integer NOT NULL,
    url text NOT NULL,
    rel character varying(30),
    comments text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    reviewed_at timestamp without time zone
);


--
-- Name: links_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.links_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: links_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.links_id_seq OWNED BY public.links.id;


--
-- Name: locations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.locations_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: locations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.locations_id_seq OWNED BY public.locations.id;


--
-- Name: magic_links; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.magic_links (
    id integer NOT NULL,
    user_id integer NOT NULL,
    token_hash text NOT NULL,
    expires_at timestamp without time zone NOT NULL,
    used_at timestamp without time zone,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: magic_links_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.magic_links_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: magic_links_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.magic_links_id_seq OWNED BY public.magic_links.id;


--
-- Name: notes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notes (
    id integer NOT NULL,
    feature_id integer NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    text text,
    source character varying(30)
);


--
-- Name: COLUMN notes.source; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.notes.source IS 'Where the note came from. NULL = written by the account owner.';


--
-- Name: notes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.notes_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: notes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.notes_id_seq OWNED BY public.notes.id;


--
-- Name: route_ratings; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.route_ratings AS
 SELECT cg.id AS group_id,
    cg.feature_id,
    f.name,
    cg.source,
    cg.url,
    (regexp_replace((d.value #>> '{}'::text[]), '[^0-9.].*$'::text, ''::text))::numeric AS miles,
    ((g.value #>> '{}'::text[]))::integer AS gain_ft,
    round(((regexp_replace((d.value #>> '{}'::text[]), '[^0-9.].*$'::text, ''::text))::numeric + ((((g.value #>> '{}'::text[]))::integer)::numeric / 500.0)), 2) AS petzoldt,
    public.petzoldt_band(round(((regexp_replace((d.value #>> '{}'::text[]), '[^0-9.].*$'::text, ''::text))::numeric + ((((g.value #>> '{}'::text[]))::integer)::numeric / 500.0)), 2)) AS band
   FROM (((public.claim_groups cg
     JOIN public.features f ON ((f.id = cg.feature_id)))
     JOIN public.claims d ON (((d.group_id = cg.id) AND ((d.field)::text = 'hike_distance'::text))))
     JOIN public.claims g ON (((g.group_id = cg.id) AND ((g.field)::text = 'elevation_gain_ft'::text))))
  WHERE ((d.value #>> '{}'::text[]) ~ '^[0-9]'::text);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    filename text NOT NULL,
    applied_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sessions (
    token text NOT NULL,
    user_id integer NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: trail_engagement; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.trail_engagement AS
 SELECT cg.id AS group_id,
    cg.feature_id,
    f.name AS feature_name,
    cg.source,
    cg.url,
    cg.identity_certain,
    ((p.value #>> '{}'::text[]))::integer AS photos,
    ((h.value #>> '{}'::text[]))::integer AS hikes,
    ((r.value #>> '{}'::text[]))::integer AS reviews,
    round((((p.value #>> '{}'::text[]))::numeric / ((h.value #>> '{}'::text[]))::numeric), 4) AS photos_per_hike
   FROM ((((public.claim_groups cg
     JOIN public.features f ON ((f.id = cg.feature_id)))
     JOIN public.claims p ON (((p.group_id = cg.id) AND ((p.field)::text = 'photos_count'::text))))
     JOIN public.claims h ON (((h.group_id = cg.id) AND ((h.field)::text = 'completed_hikes_count'::text))))
     LEFT JOIN public.claims r ON (((r.group_id = cg.id) AND ((r.field)::text = 'reviews_count'::text))))
  WHERE ((((h.value #>> '{}'::text[]))::numeric > (0)::numeric) AND cg.identity_certain);


--
-- Name: VIEW trail_engagement; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.trail_engagement IS 'Photos and completed hikes per route, with their ratio. One row per claim group, never summed onto a feature: the counts describe a walk, and the walk is not the waterfall.';


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id integer NOT NULL,
    name character varying(100) NOT NULL,
    email character varying(255) NOT NULL,
    password_digest text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    is_admin boolean DEFAULT false NOT NULL,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: visits; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.visits (
    id integer NOT NULL,
    user_id integer NOT NULL,
    feature_id integer NOT NULL,
    visited_on date NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    beauty_rating integer,
    photo_rating integer,
    solitude_rating integer,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT visits_beauty_range CHECK (((beauty_rating >= 1) AND (beauty_rating <= 4))),
    CONSTRAINT visits_photo_range CHECK (((photo_rating >= 1) AND (photo_rating <= 4))),
    CONSTRAINT visits_solitude_range CHECK (((solitude_rating >= 1) AND (solitude_rating <= 4)))
);


--
-- Name: visits_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.visits_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visits_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visits_id_seq OWNED BY public.visits.id;


--
-- Name: areas id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.areas ALTER COLUMN id SET DEFAULT nextval('public.areas_id_seq'::regclass);


--
-- Name: challenges id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.challenges ALTER COLUMN id SET DEFAULT nextval('public.challenges_id_seq'::regclass);


--
-- Name: claim_groups id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.claim_groups ALTER COLUMN id SET DEFAULT nextval('public.claim_groups_id_seq'::regclass);


--
-- Name: claims id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.claims ALTER COLUMN id SET DEFAULT nextval('public.claims_id_seq'::regclass);


--
-- Name: confusion_set_entries id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.confusion_set_entries ALTER COLUMN id SET DEFAULT nextval('public.confusion_set_entries_id_seq'::regclass);


--
-- Name: confusion_sets id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.confusion_sets ALTER COLUMN id SET DEFAULT nextval('public.confusion_sets_id_seq'::regclass);


--
-- Name: corrections id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.corrections ALTER COLUMN id SET DEFAULT nextval('public.corrections_id_seq'::regclass);


--
-- Name: facts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.facts ALTER COLUMN id SET DEFAULT nextval('public.facts_id_seq'::regclass);


--
-- Name: feature_notes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.feature_notes ALTER COLUMN id SET DEFAULT nextval('public.feature_notes_id_seq'::regclass);


--
-- Name: features id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.features ALTER COLUMN id SET DEFAULT nextval('public.features_id_seq'::regclass);


--
-- Name: goals id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.goals ALTER COLUMN id SET DEFAULT nextval('public.goals_id_seq'::regclass);


--
-- Name: links id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.links ALTER COLUMN id SET DEFAULT nextval('public.links_id_seq'::regclass);


--
-- Name: locations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.locations ALTER COLUMN id SET DEFAULT nextval('public.locations_id_seq'::regclass);


--
-- Name: magic_links id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.magic_links ALTER COLUMN id SET DEFAULT nextval('public.magic_links_id_seq'::regclass);


--
-- Name: notes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notes ALTER COLUMN id SET DEFAULT nextval('public.notes_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: visits id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visits ALTER COLUMN id SET DEFAULT nextval('public.visits_id_seq'::regclass);


--
-- Name: areas areas_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.areas
    ADD CONSTRAINT areas_name_key UNIQUE (name);


--
-- Name: areas areas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.areas
    ADD CONSTRAINT areas_pkey PRIMARY KEY (id);


--
-- Name: challenges challenges_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.challenges
    ADD CONSTRAINT challenges_name_key UNIQUE (name);


--
-- Name: challenges challenges_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.challenges
    ADD CONSTRAINT challenges_pkey PRIMARY KEY (id);


--
-- Name: challenges challenges_slug_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.challenges
    ADD CONSTRAINT challenges_slug_key UNIQUE (slug);


--
-- Name: claim_groups claim_groups_id_feature_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.claim_groups
    ADD CONSTRAINT claim_groups_id_feature_id_key UNIQUE (id, feature_id);


--
-- Name: claim_groups claim_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.claim_groups
    ADD CONSTRAINT claim_groups_pkey PRIMARY KEY (id);


--
-- Name: claim_groups claim_groups_ref_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.claim_groups
    ADD CONSTRAINT claim_groups_ref_key UNIQUE (ref);


--
-- Name: claims claims_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.claims
    ADD CONSTRAINT claims_pkey PRIMARY KEY (id);


--
-- Name: confusion_set_entries confusion_set_entries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.confusion_set_entries
    ADD CONSTRAINT confusion_set_entries_pkey PRIMARY KEY (id);


--
-- Name: confusion_set_members confusion_set_members_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.confusion_set_members
    ADD CONSTRAINT confusion_set_members_pkey PRIMARY KEY (confusion_set_id, feature_id);


--
-- Name: confusion_sets confusion_sets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.confusion_sets
    ADD CONSTRAINT confusion_sets_pkey PRIMARY KEY (id);


--
-- Name: corrections corrections_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.corrections
    ADD CONSTRAINT corrections_pkey PRIMARY KEY (id);


--
-- Name: facts facts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.facts
    ADD CONSTRAINT facts_pkey PRIMARY KEY (id);


--
-- Name: feature_areas feature_areas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.feature_areas
    ADD CONSTRAINT feature_areas_pkey PRIMARY KEY (feature_id, area_id, source);


--
-- Name: feature_notes feature_notes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.feature_notes
    ADD CONSTRAINT feature_notes_pkey PRIMARY KEY (id);


--
-- Name: feature_views feature_views_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.feature_views
    ADD CONSTRAINT feature_views_pkey PRIMARY KEY (feature_id, date);


--
-- Name: features features_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.features
    ADD CONSTRAINT features_pkey PRIMARY KEY (id);


--
-- Name: goals goals_challenge_feature_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.goals
    ADD CONSTRAINT goals_challenge_feature_key UNIQUE (challenge_id, feature_id);


--
-- Name: goals goals_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.goals
    ADD CONSTRAINT goals_pkey PRIMARY KEY (id);


--
-- Name: links links_feature_id_url_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.links
    ADD CONSTRAINT links_feature_id_url_key UNIQUE (feature_id, url);


--
-- Name: links links_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.links
    ADD CONSTRAINT links_pkey PRIMARY KEY (id);


--
-- Name: locations locations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.locations
    ADD CONSTRAINT locations_pkey PRIMARY KEY (id);


--
-- Name: magic_links magic_links_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.magic_links
    ADD CONSTRAINT magic_links_pkey PRIMARY KEY (id);


--
-- Name: magic_links magic_links_token_hash_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.magic_links
    ADD CONSTRAINT magic_links_token_hash_key UNIQUE (token_hash);


--
-- Name: notes notes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notes
    ADD CONSTRAINT notes_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (filename);


--
-- Name: sessions sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (token);


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: visits visits_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visits
    ADD CONSTRAINT visits_pkey PRIMARY KEY (id);


--
-- Name: visits visits_user_feature_date_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visits
    ADD CONSTRAINT visits_user_feature_date_key UNIQUE (user_id, feature_id, visited_on);


--
-- Name: areas_slug_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX areas_slug_key ON public.areas USING btree (slug);


--
-- Name: claim_groups_feature_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX claim_groups_feature_idx ON public.claim_groups USING btree (feature_id);


--
-- Name: claim_groups_source_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX claim_groups_source_idx ON public.claim_groups USING btree (source);


--
-- Name: claims_feature_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX claims_feature_idx ON public.claims USING btree (feature_id);


--
-- Name: claims_field_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX claims_field_idx ON public.claims USING btree (field);


--
-- Name: claims_one_accepted; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX claims_one_accepted ON public.claims USING btree (feature_id, field) WHERE (accepted AND ((field)::text <> 'alias'::text));


--
-- Name: claims_one_value_per_group; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX claims_one_value_per_group ON public.claims USING btree (group_id, field, value);


--
-- Name: confusion_set_entries_set; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX confusion_set_entries_set ON public.confusion_set_entries USING btree (confusion_set_id, created_at DESC);


--
-- Name: confusion_set_members_feature; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX confusion_set_members_feature ON public.confusion_set_members USING btree (feature_id);


--
-- Name: corrections_feature_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX corrections_feature_idx ON public.corrections USING btree (feature_id);


--
-- Name: corrections_open_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX corrections_open_idx ON public.corrections USING btree (status, created_at DESC);


--
-- Name: facts_feature_key; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX facts_feature_key ON public.facts USING btree (feature_id, key);


--
-- Name: feature_areas_area_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX feature_areas_area_idx ON public.feature_areas USING btree (area_id);


--
-- Name: feature_notes_feature_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX feature_notes_feature_id ON public.feature_notes USING btree (feature_id);


--
-- Name: features_deprecated_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX features_deprecated_idx ON public.features USING btree (deprecated_reason) WHERE (deprecated_reason IS NOT NULL);


--
-- Name: features_slug_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX features_slug_key ON public.features USING btree (slug);


--
-- Name: links_feature_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX links_feature_idx ON public.links USING btree (feature_id);


--
-- Name: links_url_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX links_url_idx ON public.links USING btree (url);


--
-- Name: magic_links_user_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX magic_links_user_idx ON public.magic_links USING btree (user_id, created_at DESC);


--
-- Name: visits_user_feature_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX visits_user_feature_idx ON public.visits USING btree (user_id, feature_id);


--
-- Name: confusion_set_entries append_only; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER append_only BEFORE DELETE OR UPDATE ON public.confusion_set_entries FOR EACH ROW EXECUTE FUNCTION public.confusion_set_entries_are_append_only();


--
-- Name: areas touch_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER touch_updated_at BEFORE UPDATE ON public.areas FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();


--
-- Name: challenges touch_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER touch_updated_at BEFORE UPDATE ON public.challenges FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();


--
-- Name: claim_groups touch_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER touch_updated_at BEFORE UPDATE ON public.claim_groups FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();


--
-- Name: claims touch_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER touch_updated_at BEFORE UPDATE ON public.claims FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();


--
-- Name: confusion_sets touch_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER touch_updated_at BEFORE UPDATE ON public.confusion_sets FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();


--
-- Name: corrections touch_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER touch_updated_at BEFORE UPDATE ON public.corrections FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();


--
-- Name: facts touch_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER touch_updated_at BEFORE UPDATE ON public.facts FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();


--
-- Name: feature_areas touch_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER touch_updated_at BEFORE UPDATE ON public.feature_areas FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();


--
-- Name: feature_notes touch_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER touch_updated_at BEFORE UPDATE ON public.feature_notes FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();


--
-- Name: feature_views touch_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER touch_updated_at BEFORE UPDATE ON public.feature_views FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();


--
-- Name: features touch_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER touch_updated_at BEFORE UPDATE ON public.features FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();


--
-- Name: goals touch_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER touch_updated_at BEFORE UPDATE ON public.goals FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();


--
-- Name: links touch_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER touch_updated_at BEFORE UPDATE ON public.links FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();


--
-- Name: locations touch_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER touch_updated_at BEFORE UPDATE ON public.locations FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();


--
-- Name: magic_links touch_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER touch_updated_at BEFORE UPDATE ON public.magic_links FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();


--
-- Name: sessions touch_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER touch_updated_at BEFORE UPDATE ON public.sessions FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();


--
-- Name: users touch_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER touch_updated_at BEFORE UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();


--
-- Name: visits touch_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER touch_updated_at BEFORE UPDATE ON public.visits FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();


--
-- Name: claim_groups claim_groups_feature_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.claim_groups
    ADD CONSTRAINT claim_groups_feature_id_fkey FOREIGN KEY (feature_id) REFERENCES public.features(id) ON DELETE CASCADE;


--
-- Name: claims claims_fact_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.claims
    ADD CONSTRAINT claims_fact_id_fkey FOREIGN KEY (fact_id) REFERENCES public.facts(id) ON DELETE SET NULL;


--
-- Name: claims claims_group_id_feature_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.claims
    ADD CONSTRAINT claims_group_id_feature_id_fkey FOREIGN KEY (group_id, feature_id) REFERENCES public.claim_groups(id, feature_id) ON DELETE CASCADE;


--
-- Name: confusion_set_entries confusion_set_entries_confusion_set_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.confusion_set_entries
    ADD CONSTRAINT confusion_set_entries_confusion_set_id_fkey FOREIGN KEY (confusion_set_id) REFERENCES public.confusion_sets(id) ON DELETE CASCADE;


--
-- Name: confusion_set_members confusion_set_members_confusion_set_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.confusion_set_members
    ADD CONSTRAINT confusion_set_members_confusion_set_id_fkey FOREIGN KEY (confusion_set_id) REFERENCES public.confusion_sets(id) ON DELETE CASCADE;


--
-- Name: confusion_set_members confusion_set_members_feature_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.confusion_set_members
    ADD CONSTRAINT confusion_set_members_feature_id_fkey FOREIGN KEY (feature_id) REFERENCES public.features(id) ON DELETE CASCADE;


--
-- Name: corrections corrections_feature_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.corrections
    ADD CONSTRAINT corrections_feature_id_fkey FOREIGN KEY (feature_id) REFERENCES public.features(id) ON DELETE CASCADE;


--
-- Name: corrections corrections_resolved_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.corrections
    ADD CONSTRAINT corrections_resolved_by_fkey FOREIGN KEY (resolved_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: corrections corrections_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.corrections
    ADD CONSTRAINT corrections_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: facts facts_feature_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.facts
    ADD CONSTRAINT facts_feature_id_fkey FOREIGN KEY (feature_id) REFERENCES public.features(id) ON DELETE CASCADE;


--
-- Name: feature_areas feature_areas_area_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.feature_areas
    ADD CONSTRAINT feature_areas_area_id_fkey FOREIGN KEY (area_id) REFERENCES public.areas(id) ON DELETE CASCADE;


--
-- Name: feature_areas feature_areas_feature_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.feature_areas
    ADD CONSTRAINT feature_areas_feature_id_fkey FOREIGN KEY (feature_id) REFERENCES public.features(id) ON DELETE CASCADE;


--
-- Name: feature_notes feature_notes_feature_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.feature_notes
    ADD CONSTRAINT feature_notes_feature_id_fkey FOREIGN KEY (feature_id) REFERENCES public.features(id);


--
-- Name: feature_views feature_views_feature_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.feature_views
    ADD CONSTRAINT feature_views_feature_id_fkey FOREIGN KEY (feature_id) REFERENCES public.features(id);


--
-- Name: features features_view_location_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.features
    ADD CONSTRAINT features_view_location_id_fkey FOREIGN KEY (view_location_id) REFERENCES public.locations(id);


--
-- Name: goals goals_challenge_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.goals
    ADD CONSTRAINT goals_challenge_id_fkey FOREIGN KEY (challenge_id) REFERENCES public.challenges(id) ON DELETE CASCADE;


--
-- Name: goals goals_feature_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.goals
    ADD CONSTRAINT goals_feature_id_fkey FOREIGN KEY (feature_id) REFERENCES public.features(id) ON DELETE CASCADE;


--
-- Name: links links_feature_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.links
    ADD CONSTRAINT links_feature_id_fkey FOREIGN KEY (feature_id) REFERENCES public.features(id) ON DELETE CASCADE;


--
-- Name: magic_links magic_links_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.magic_links
    ADD CONSTRAINT magic_links_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: notes notes_feature_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notes
    ADD CONSTRAINT notes_feature_id_fkey FOREIGN KEY (feature_id) REFERENCES public.features(id) ON DELETE CASCADE;


--
-- Name: sessions sessions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT sessions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: visits visits_feature_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visits
    ADD CONSTRAINT visits_feature_id_fkey FOREIGN KEY (feature_id) REFERENCES public.features(id) ON DELETE CASCADE;


--
-- Name: visits visits_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visits
    ADD CONSTRAINT visits_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

\unrestrict wS0KYLIV3qXhIpdZ7DQYT14hl5PRGCja1MPuAwkkkCBcZBJA0UzerlLa1dcA3NZ

