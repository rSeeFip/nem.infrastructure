# Isolated rehearsal test plan

## Gate and isolation

This plan is for a disposable clone only, after parent-Oracle approval. It must
not target production, start or modify the retained inspection clone, or invoke
backup automation. SSH may only manage the new isolated clone's explicit unit,
PGDATA, private socket/port, and filesystem; it must not address production
PostgreSQL or its files. Record host, cluster, database, package version, server
version, and a positive disposable-clone attestation before any SQL.

Immediately before SQL, verify the source manifest and both pinned upstream SQL
hashes inside the clone namespace, PostgreSQL 16.15, and the pinned PGDG package.
Require no application traffic or other database sessions. Set finite shell,
statement, and lock timeouts. Capture the extension owner's global and
`ag_catalog` default ACL policies; compare new objects with a fresh reference
under identical policies, without discarding unexplained ACL differences.

The rehearsal must use PostgreSQL 16, an AGE 1.5.0 catalog produced by the
pinned PG16 source, and the PGDG `1.6.0rc0-2` library/package already verified
against commit `2db2f060c4c9265a14d40f007eb8c56febf31e4c`.

## Baseline evidence

1. Hash the installed official `age--1.5.0--1.6.0.sql` and require
   `44b6c775d880530e6c50937966ff879701a614d194dfcf99ec3d6e3f959c6f9f`.
2. Capture server version, AGE version/schema/owner, caller identity and
   superuser status, every AGE extension member identity/definition/owner/ACL,
   and all dependencies on the five obsolete identities.
3. Require the four 1.5 function fingerprints encoded in the preflight and an
   inert extension-member `?(text,agtype)` shell with `oprcode = 0`.
4. Capture graph IDs/names/schemas; graph, schema, label relation, and sequence
   owners/ACLs; label IDs/kinds/relation and sequence identities; constraints;
   indexes; sequence state; row counts; and ordered binary-safe row/property
   hashes. Retain the raw graph rows for byte-exact comparison.

## Positive rehearsal

1. Run only `apply-age-1.6-catalog-parity.sql` with `psql --no-psqlrc` and
   `ON_ERROR_STOP=1`, saving stdout, stderr, exit status, and transaction status.
2. Require one committed transaction, AGE version 1.6.0, all four new functions
   and the explicit cast attached to AGE, exact `$libdir/age`/linker symbols,
   exact volatility/strictness/parallel/default attributes, extension ownership,
   and ACLs resulting from the extension owner's default ACL policy.
3. Require the four obsolete overloads and reverse shell absent. Require no
   other extension-member identity or normalized definition difference from a
   fresh 1.6 database built from generated SQL SHA-256
   `861b39655aa79f076aefcfd3a5e151133659f3dd55eba53bc45dda80e39eba7e`.
4. Re-capture the complete graph state and require byte-exact equality for raw
   graph rows plus equality of every ID, owner, ACL, relation/sequence identity,
   sequence value, count, hash, constraint, and index captured at baseline.
5. Run representative calls for both new loader signatures only against
   disposable files/data, and exercise integer/text coercions. Keep functional
   test data outside the baseline graph-state comparison.

## Required fail-closed cases

Run each case from a fresh disposable snapshot and require nonzero exit, full
transaction rollback, unchanged AGE version/catalog, and byte-exact graph state:

- PostgreSQL 15 or 17; missing AGE; AGE outside `ag_catalog`; AGE version other
  than 1.5.0 at wrapper entry; fresh 1.6; and already repaired 1.6.
- Caller is neither extension owner nor superuser; superuser caller with a
  distinct extension owner verifies owner switching and default ACL behavior.
- Any one old function missing, changed, re-owned, re-ACL'd, remapped away from
  `$libdir/age`, or carrying an external dependency.
- Any one new function or the integer-to-agtype cast pre-created, including a
  partial prior repair.
- Reverse operator missing, not an AGE member, externally depended upon, or
  changed from an inert shell, especially nonzero `oprcode`.
- Official update failure and every supplement DDL failure point, proving the
  official `ALTER EXTENSION` rolls back with the supplement.
- Direct invocation of `age-1.6-catalog-parity-repair.sql`, proving the local
  transaction marker guard rejects it.

## Handoff evidence

Archive command transcripts, stderr, package/source hashes, pre/post catalog
inventories, normalized fresh-vs-upgraded diff, pre/post graph captures, and all
negative-case rollback proofs. Parent Oracle must approve that bundle before any
live action is proposed. Passing this plan does not make the repair vendor
supported.
