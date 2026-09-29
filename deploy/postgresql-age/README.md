# PostgreSQL AGE 1.6 catalog-parity supplement

This directory contains local revision 1 of the narrowly scoped PostgreSQL 16
AGE 1.5.0 to 1.6.0 catalog repair. It supplements, but never edits or replaces,
the installed official update script.

## Scope

The supplement creates the four fresh-1.6-only functions and explicit
integer-to-agtype cast, attaches them to the AGE extension, and removes only the
four proven obsolete 1.5 overloads and inert reverse `?` shell. It performs no
extension, graph, schema, table, or graph-data drop; no catalog update; no
`CASCADE`; no grant; and no owner or ACL weakening.

All DDL executes as the actual extension owner, including superuser-initiated
runs, so that role's default ACL policy is applied. New C functions map
explicitly to `$libdir/age`; `MODULE_PATHNAME` is not used outside a vendor
extension script.

## Entry point

The only supported entry point is:

```text
psql --no-psqlrc --set=ON_ERROR_STOP=1 --file=apply-age-1.6-catalog-parity.sql DATABASE
```

Do not run the supplement directly. The wrapper requires an exact AGE 1.5.0
starting catalog, runs the installed official `ALTER EXTENSION ... UPDATE TO
'1.6.0'`, and includes the supplement before commit. A fresh 1.6 install, an
already repaired database, a partial repair, a modified old object, an external
dependency, a non-inert reverse operator, a different server/extension version,
or an unauthorized caller fails closed and rolls back the transaction.

This command is documentation only. It was not run while preparing these files.
The mandatory downstream sequence is parent-Oracle review, then an isolated
fresh-clone rehearsal following `TESTPLAN.md`, before any live consideration.

See `PROVENANCE.md` for pinned upstream identities and `MANIFEST.sha256` for
local artifact hashes. This repair is locally maintained and is not claimed to
be vendor-supported.
