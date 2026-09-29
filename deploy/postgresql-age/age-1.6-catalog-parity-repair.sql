-- Locally maintained AGE 1.5.0 -> 1.6.0 catalog-parity supplement, revision 1.
-- Run only through apply-age-1.6-catalog-parity.sql immediately after the
-- official ALTER EXTENSION, in the same transaction.

DO $preflight$
DECLARE
    age_extension oid;
    extension_owner oid;
    installed_version text;
    is_superuser boolean;
    function_oid oid;
    operator_oid oid;
    dependent_count bigint;
    expected_signatures constant text[] := ARRAY[
        'ag_catalog.create_vlabel(name,name)',
        'ag_catalog.create_elabel(name,name)',
        'ag_catalog.load_edges_from_file(name,name,text)',
        'ag_catalog.load_labels_from_file(name,name,text,boolean)'
    ];
    expected_sources constant text[] := ARRAY[
        'create_vlabel',
        'create_elabel',
        'load_edges_from_file',
        'load_labels_from_file'
    ];
    expected_names text[];
    expected_default_count integer;
    actual record;
    signature text;
BEGIN
    IF pg_catalog.current_setting('server_version_num')::integer / 10000 <> 16 THEN
        RAISE EXCEPTION 'AGE catalog repair requires PostgreSQL 16';
    END IF;
    IF pg_catalog.current_setting(
        'age_catalog_repair.official_upgrade',
        true
    ) IS DISTINCT FROM '1.5.0-to-1.6.0-local-v1' THEN
        RAISE EXCEPTION 'run the supplement through apply-age-1.6-catalog-parity.sql';
    END IF;

    SELECT e.oid, e.extowner, e.extversion
      INTO age_extension, extension_owner, installed_version
      FROM pg_catalog.pg_extension AS e
      JOIN pg_catalog.pg_namespace AS n ON n.oid = e.extnamespace
     WHERE e.extname = 'age'
       AND n.nspname = 'ag_catalog';

    IF NOT FOUND OR installed_version <> '1.6.0' THEN
        RAISE EXCEPTION 'expected AGE 1.6.0 in schema ag_catalog after official update';
    END IF;

    SELECT r.rolsuper
      INTO STRICT is_superuser
      FROM pg_catalog.pg_roles AS r
     WHERE r.rolname = current_user;
    IF pg_catalog.to_regrole(current_user) <> extension_owner AND NOT is_superuser THEN
        RAISE EXCEPTION 'current user must be the AGE extension owner or a superuser';
    END IF;

    FOREACH signature IN ARRAY ARRAY[
        'ag_catalog.create_vlabel(cstring,cstring)',
        'ag_catalog.create_elabel(cstring,cstring)'
    ]
    LOOP
        function_oid := pg_catalog.to_regprocedure(signature);
        IF function_oid IS NULL THEN
            RAISE EXCEPTION 'missing expected official 1.6 function %', signature;
        END IF;
        SELECT p.probin, p.prosrc, p.prorettype, p.prolang, p.proowner,
               p.provolatile, p.proisstrict, p.prosecdef, p.proleakproof,
               p.proparallel, p.prokind
          INTO actual
          FROM pg_catalog.pg_proc AS p
         WHERE p.oid = function_oid;
        IF actual.probin IS DISTINCT FROM '$libdir/age'
           OR actual.prosrc IS DISTINCT FROM pg_catalog.split_part(
               pg_catalog.split_part(signature, '.', 2), '(', 1
           )
           OR actual.prorettype <> 'pg_catalog.void'::pg_catalog.regtype
           OR actual.prolang <> (SELECT oid FROM pg_catalog.pg_language WHERE lanname = 'c')
           OR actual.proowner <> extension_owner
           OR actual.provolatile <> 'v'
           OR actual.proisstrict
           OR actual.prosecdef
           OR actual.proleakproof
           OR actual.proparallel <> 'u'
           OR actual.prokind <> 'f' THEN
            RAISE EXCEPTION 'unexpected definition for official 1.6 function %', signature;
        END IF;
    END LOOP;

    FOR array_index IN 1..pg_catalog.array_length(expected_signatures, 1)
    LOOP
        signature := expected_signatures[array_index];
        function_oid := pg_catalog.to_regprocedure(signature);
        IF function_oid IS NULL THEN
            RAISE EXCEPTION 'missing expected obsolete function %', signature;
        END IF;

        IF array_index <= 2 THEN
            expected_names := ARRAY['graph_name', 'label_name'];
            expected_default_count := 0;
        ELSIF array_index = 3 THEN
            expected_names := ARRAY['graph_name', 'label_name', 'file_path'];
            expected_default_count := 0;
        ELSE
            expected_names := ARRAY[
                'graph_name', 'label_name', 'file_path', 'id_field_exists'
            ];
            expected_default_count := 1;
        END IF;

        SELECT p.probin, p.prosrc, p.prorettype, p.prolang, p.proowner,
               p.provolatile, p.proisstrict, p.prosecdef, p.proleakproof,
               p.proparallel, p.prokind, p.proargnames, p.pronargdefaults,
               p.proacl, pg_catalog.pg_get_expr(p.proargdefaults, 0) AS default_expr
          INTO actual
          FROM pg_catalog.pg_proc AS p
         WHERE p.oid = function_oid;

        IF actual.probin IS DISTINCT FROM '$libdir/age'
           OR actual.prosrc IS DISTINCT FROM expected_sources[array_index]
           OR actual.prorettype <> 'pg_catalog.void'::pg_catalog.regtype
           OR actual.prolang <> (SELECT oid FROM pg_catalog.pg_language WHERE lanname = 'c')
           OR actual.proowner <> extension_owner
           OR actual.provolatile <> 'v'
           OR actual.proisstrict
           OR actual.prosecdef
           OR actual.proleakproof
           OR actual.proparallel <> 'u'
           OR actual.prokind <> 'f'
           OR actual.proargnames IS DISTINCT FROM expected_names
           OR actual.pronargdefaults <> expected_default_count
           OR (expected_default_count = 1 AND actual.default_expr IS DISTINCT FROM 'true')
           OR actual.proacl IS NOT NULL THEN
            RAISE EXCEPTION 'obsolete function % does not match the AGE 1.5 fingerprint', signature;
        END IF;

        IF NOT EXISTS (
            SELECT 1
              FROM pg_catalog.pg_depend AS d
             WHERE d.classid = 'pg_catalog.pg_proc'::pg_catalog.regclass
               AND d.objid = function_oid
               AND d.refclassid = 'pg_catalog.pg_extension'::pg_catalog.regclass
               AND d.refobjid = age_extension
               AND d.deptype = 'e'
        ) THEN
            RAISE EXCEPTION 'obsolete function % is not an AGE extension member', signature;
        END IF;

        SELECT pg_catalog.count(*)
          INTO dependent_count
          FROM pg_catalog.pg_depend AS d
         WHERE d.refclassid = 'pg_catalog.pg_proc'::pg_catalog.regclass
           AND d.refobjid = function_oid;
        IF dependent_count <> 0 THEN
            RAISE EXCEPTION 'obsolete function % has % dependent object(s)',
                signature, dependent_count;
        END IF;
    END LOOP;

    FOREACH signature IN ARRAY ARRAY[
        'ag_catalog.int4_to_agtype(integer)',
        'ag_catalog.text_to_agtype(text)',
        'ag_catalog.load_edges_from_file(name,name,text,boolean)',
        'ag_catalog.load_labels_from_file(name,name,text,boolean,boolean)'
    ]
    LOOP
        IF pg_catalog.to_regprocedure(signature) IS NOT NULL THEN
            RAISE EXCEPTION 'new function already exists: %', signature;
        END IF;
    END LOOP;
    IF EXISTS (
        SELECT 1
          FROM pg_catalog.pg_cast AS c
         WHERE c.castsource = 'pg_catalog.int4'::pg_catalog.regtype
           AND c.casttarget = 'ag_catalog.agtype'::pg_catalog.regtype
    ) THEN
        RAISE EXCEPTION 'integer-to-agtype cast already exists';
    END IF;

    SELECT o.oid
      INTO operator_oid
      FROM pg_catalog.pg_operator AS o
     WHERE o.oprnamespace = 'ag_catalog'::pg_catalog.regnamespace
       AND o.oprname = '?'
       AND o.oprleft = 'pg_catalog.text'::pg_catalog.regtype
       AND o.oprright = 'ag_catalog.agtype'::pg_catalog.regtype;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'expected obsolete reverse ?(text,agtype) shell operator';
    END IF;

    SELECT o.oprowner, o.oprkind, o.oprcanmerge, o.oprcanhash, o.oprresult,
           o.oprcode, o.oprrest, o.oprjoin
      INTO actual
      FROM pg_catalog.pg_operator AS o
     WHERE o.oid = operator_oid;
    IF actual.oprowner <> extension_owner
       OR actual.oprkind <> 'b'
       OR actual.oprcanmerge
       OR actual.oprcanhash
       OR actual.oprresult <> 0
       OR actual.oprcode <> 0
       OR actual.oprrest <> 0
       OR actual.oprjoin <> 0 THEN
        RAISE EXCEPTION 'reverse ?(text,agtype) is not the expected inert AGE 1.5 shell';
    END IF;
    IF NOT EXISTS (
        SELECT 1
          FROM pg_catalog.pg_depend AS d
         WHERE d.classid = 'pg_catalog.pg_operator'::pg_catalog.regclass
           AND d.objid = operator_oid
           AND d.refclassid = 'pg_catalog.pg_extension'::pg_catalog.regclass
           AND d.refobjid = age_extension
           AND d.deptype = 'e'
    ) THEN
        RAISE EXCEPTION 'reverse ?(text,agtype) shell is not an AGE extension member';
    END IF;
    SELECT pg_catalog.count(*)
      INTO dependent_count
      FROM pg_catalog.pg_depend AS d
     WHERE d.refclassid = 'pg_catalog.pg_operator'::pg_catalog.regclass
       AND d.refobjid = operator_oid;
    IF dependent_count <> 0 THEN
        RAISE EXCEPTION 'reverse ?(text,agtype) shell has % dependent object(s)', dependent_count;
    END IF;
END
$preflight$;

-- Creating as the extension owner applies that role's default ACL policy even
-- when a superuser invoked the wrapper.  The role change is transaction-local.
SELECT pg_catalog.format('SET LOCAL ROLE %I', owner_role.rolname)
  FROM pg_catalog.pg_extension AS e
  JOIN pg_catalog.pg_roles AS owner_role ON owner_role.oid = e.extowner
 WHERE e.extname = 'age'
\gexec

ALTER EXTENSION age DROP FUNCTION ag_catalog.create_vlabel(name, name);
DROP FUNCTION ag_catalog.create_vlabel(name, name) RESTRICT;
ALTER EXTENSION age DROP FUNCTION ag_catalog.create_elabel(name, name);
DROP FUNCTION ag_catalog.create_elabel(name, name) RESTRICT;
ALTER EXTENSION age DROP FUNCTION ag_catalog.load_edges_from_file(name, name, text);
DROP FUNCTION ag_catalog.load_edges_from_file(name, name, text) RESTRICT;
ALTER EXTENSION age DROP FUNCTION ag_catalog.load_labels_from_file(name, name, text, boolean);
DROP FUNCTION ag_catalog.load_labels_from_file(name, name, text, boolean) RESTRICT;
ALTER EXTENSION age DROP OPERATOR ag_catalog.? (text, ag_catalog.agtype);
DROP OPERATOR ag_catalog.? (text, ag_catalog.agtype) RESTRICT;

CREATE FUNCTION ag_catalog.int4_to_agtype(int4)
    RETURNS ag_catalog.agtype
    LANGUAGE c
    IMMUTABLE
RETURNS NULL ON NULL INPUT
PARALLEL SAFE
AS '$libdir/age';

CREATE CAST (int4 AS ag_catalog.agtype)
    WITH FUNCTION ag_catalog.int4_to_agtype(int4);

CREATE FUNCTION ag_catalog.text_to_agtype(text)
    RETURNS ag_catalog.agtype
    LANGUAGE c
    IMMUTABLE
RETURNS NULL ON NULL INPUT
PARALLEL SAFE
AS '$libdir/age';

CREATE FUNCTION ag_catalog.load_labels_from_file(graph_name name,
                                                 label_name name,
                                                 file_path text,
                                                 id_field_exists bool DEFAULT true,
                                                 load_as_agtype bool DEFAULT false)
    RETURNS void
    LANGUAGE c
    AS '$libdir/age';

CREATE FUNCTION ag_catalog.load_edges_from_file(graph_name name,
                                                label_name name,
                                                file_path text,
                                                load_as_agtype bool DEFAULT false)
    RETURNS void
    LANGUAGE c
    AS '$libdir/age';

ALTER EXTENSION age ADD FUNCTION ag_catalog.int4_to_agtype(int4);
ALTER EXTENSION age ADD CAST (int4 AS ag_catalog.agtype);
ALTER EXTENSION age ADD FUNCTION ag_catalog.text_to_agtype(text);
ALTER EXTENSION age ADD FUNCTION ag_catalog.load_labels_from_file(name, name, text, boolean, boolean);
ALTER EXTENSION age ADD FUNCTION ag_catalog.load_edges_from_file(name, name, text, boolean);

DO $postflight$
DECLARE
    age_extension oid;
    extension_owner oid;
    function_oid oid;
    cast_oid oid;
    actual record;
    signature text;
BEGIN
    SELECT e.oid, e.extowner
      INTO STRICT age_extension, extension_owner
      FROM pg_catalog.pg_extension AS e
     WHERE e.extname = 'age'
       AND e.extversion = '1.6.0';

    IF pg_catalog.to_regrole(current_user) <> extension_owner THEN
        RAISE EXCEPTION 'repair DDL was not executed as the AGE extension owner';
    END IF;

    FOREACH signature IN ARRAY ARRAY[
        'ag_catalog.create_vlabel(name,name)',
        'ag_catalog.create_elabel(name,name)',
        'ag_catalog.load_edges_from_file(name,name,text)',
        'ag_catalog.load_labels_from_file(name,name,text,boolean)'
    ]
    LOOP
        IF pg_catalog.to_regprocedure(signature) IS NOT NULL THEN
            RAISE EXCEPTION 'obsolete function remains after repair: %', signature;
        END IF;
    END LOOP;
    IF EXISTS (
        SELECT 1
          FROM pg_catalog.pg_operator AS o
         WHERE o.oprnamespace = 'ag_catalog'::pg_catalog.regnamespace
           AND o.oprname = '?'
           AND o.oprleft = 'pg_catalog.text'::pg_catalog.regtype
           AND o.oprright = 'ag_catalog.agtype'::pg_catalog.regtype
    ) THEN
        RAISE EXCEPTION 'obsolete reverse ?(text,agtype) shell remains after repair';
    END IF;

    FOREACH signature IN ARRAY ARRAY[
        'ag_catalog.int4_to_agtype(integer)',
        'ag_catalog.text_to_agtype(text)',
        'ag_catalog.load_edges_from_file(name,name,text,boolean)',
        'ag_catalog.load_labels_from_file(name,name,text,boolean,boolean)'
    ]
    LOOP
        function_oid := pg_catalog.to_regprocedure(signature);
        IF function_oid IS NULL THEN
            RAISE EXCEPTION 'new function is missing after repair: %', signature;
        END IF;
        SELECT p.probin, p.prosrc, p.proowner, p.provolatile, p.proisstrict,
               p.prosecdef, p.proleakproof, p.proparallel, p.prokind,
               p.proargnames, p.pronargdefaults,
               pg_catalog.pg_get_expr(p.proargdefaults, 0) AS default_expr
          INTO actual
          FROM pg_catalog.pg_proc AS p
         WHERE p.oid = function_oid;
        IF actual.probin IS DISTINCT FROM '$libdir/age'
           OR actual.proowner <> extension_owner
           OR actual.prosecdef
           OR actual.proleakproof
           OR actual.prokind <> 'f'
           OR NOT EXISTS (
               SELECT 1
                 FROM pg_catalog.pg_depend AS d
                WHERE d.classid = 'pg_catalog.pg_proc'::pg_catalog.regclass
                  AND d.objid = function_oid
                  AND d.refclassid = 'pg_catalog.pg_extension'::pg_catalog.regclass
                  AND d.refobjid = age_extension
                  AND d.deptype = 'e'
           ) THEN
            RAISE EXCEPTION 'new function has an unexpected definition or membership: %', signature;
        END IF;
    END LOOP;

    SELECT p.prosrc, p.provolatile, p.proisstrict, p.proparallel
      INTO actual
      FROM pg_catalog.pg_proc AS p
     WHERE p.oid = 'ag_catalog.int4_to_agtype(integer)'::pg_catalog.regprocedure;
    IF actual.prosrc <> 'int4_to_agtype' OR actual.provolatile <> 'i'
       OR NOT actual.proisstrict OR actual.proparallel <> 's' THEN
        RAISE EXCEPTION 'int4_to_agtype does not match fresh AGE 1.6';
    END IF;
    SELECT p.prosrc, p.provolatile, p.proisstrict, p.proparallel
      INTO actual
      FROM pg_catalog.pg_proc AS p
     WHERE p.oid = 'ag_catalog.text_to_agtype(text)'::pg_catalog.regprocedure;
    IF actual.prosrc <> 'text_to_agtype' OR actual.provolatile <> 'i'
       OR NOT actual.proisstrict OR actual.proparallel <> 's' THEN
        RAISE EXCEPTION 'text_to_agtype does not match fresh AGE 1.6';
    END IF;
    SELECT p.prosrc, p.provolatile, p.proisstrict, p.proparallel,
           p.proargnames, p.pronargdefaults,
           pg_catalog.pg_get_expr(p.proargdefaults, 0) AS default_expr
      INTO actual
      FROM pg_catalog.pg_proc AS p
     WHERE p.oid = 'ag_catalog.load_edges_from_file(name,name,text,boolean)'::pg_catalog.regprocedure;
    IF actual.prosrc <> 'load_edges_from_file' OR actual.provolatile <> 'v'
       OR actual.proisstrict OR actual.proparallel <> 'u'
       OR actual.proargnames IS DISTINCT FROM
          ARRAY['graph_name', 'label_name', 'file_path', 'load_as_agtype']
       OR actual.pronargdefaults <> 1 OR actual.default_expr IS DISTINCT FROM 'false' THEN
        RAISE EXCEPTION 'load_edges_from_file does not match fresh AGE 1.6';
    END IF;
    SELECT p.prosrc, p.provolatile, p.proisstrict, p.proparallel,
           p.proargnames, p.pronargdefaults,
           pg_catalog.pg_get_expr(p.proargdefaults, 0) AS default_expr
      INTO actual
      FROM pg_catalog.pg_proc AS p
     WHERE p.oid = 'ag_catalog.load_labels_from_file(name,name,text,boolean,boolean)'::pg_catalog.regprocedure;
    IF actual.prosrc <> 'load_labels_from_file' OR actual.provolatile <> 'v'
       OR actual.proisstrict OR actual.proparallel <> 'u'
       OR actual.proargnames IS DISTINCT FROM ARRAY[
           'graph_name', 'label_name', 'file_path', 'id_field_exists', 'load_as_agtype'
       ]
       OR actual.pronargdefaults <> 2
       OR actual.default_expr IS DISTINCT FROM 'true, false' THEN
        RAISE EXCEPTION 'load_labels_from_file does not match fresh AGE 1.6';
    END IF;

    SELECT c.oid
      INTO cast_oid
      FROM pg_catalog.pg_cast AS c
     WHERE c.castsource = 'pg_catalog.int4'::pg_catalog.regtype
       AND c.casttarget = 'ag_catalog.agtype'::pg_catalog.regtype
       AND c.castfunc = 'ag_catalog.int4_to_agtype(integer)'::pg_catalog.regprocedure
       AND c.castcontext = 'e'
       AND c.castmethod = 'f';
    IF NOT FOUND OR NOT EXISTS (
        SELECT 1
          FROM pg_catalog.pg_depend AS d
         WHERE d.classid = 'pg_catalog.pg_cast'::pg_catalog.regclass
           AND d.objid = cast_oid
           AND d.refclassid = 'pg_catalog.pg_extension'::pg_catalog.regclass
           AND d.refobjid = age_extension
           AND d.deptype = 'e'
    ) THEN
        RAISE EXCEPTION 'integer-to-agtype cast does not match fresh AGE 1.6 membership';
    END IF;
END
$postflight$;
