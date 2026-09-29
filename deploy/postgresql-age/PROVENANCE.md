# AGE 1.6 catalog-parity repair provenance

This is a locally maintained repair, not an Apache AGE or PGDG-supported
upgrade. The vendor update file is intentionally not copied or modified here.
`ALTER EXTENSION` resolves the installed vendor file, and the local supplement
runs immediately afterward in the same transaction.

| Artifact | Identity | SHA-256 |
|---|---|---|
| Apache AGE PG16 1.6 tag | commit `2db2f060c4c9265a14d40f007eb8c56febf31e4c` | n/a |
| Official `age--1.5.0--1.6.0.sql` | tag `PG16/v1.6.0-rc0` | `44b6c775d880530e6c50937966ff879701a614d194dfcf99ec3d6e3f959c6f9f` |
| Generated fresh-install SQL | AGE 1.6 / PostgreSQL 16 | `861b39655aa79f076aefcfd3a5e151133659f3dd55eba53bc45dda80e39eba7e` |
| `sql/agtype_coercions.sql` | commit above | `9c41ecdf8f6c5b92971714e25abe3dc44ef6a0db436e0d74ed340cbf17a042ee` |
| `sql/age_main.sql` | commit above | `543077146a4ef0fb6f9f719c59167ebe0197fb026a0d1c99aab4489989716ab7` |
| Installed library/package source | PGDG `1.6.0rc0-2` | exact package source previously verified |

Fresh DDL was transcribed from the two named source files at the pinned commit.
Outside extension-script context, `MODULE_PATHNAME` is correctly resolved as the
control-file mapping `$libdir/age`; the C linker symbols remain the SQL function
names exactly as in the fresh install.

The reverse `ag_catalog.?(text,ag_catalog.agtype)` object is not explicit DDL.
PG16 AGE 1.5 declares `COMMUTATOR = '?'` on `?(agtype,text)`, which creates the
reverse shell. The repair removes it only if its catalog fingerprint proves it
is still inert (`oprcode = 0`) and has no dependents.

## Production receipt

This remains a **locally maintained** repair; the installed upstream update
file was neither vendored nor modified. The original failure was a missing AGE
`LOAD` in the upgrade execution path, not a lack of PostgreSQL 16 support.

Authorized production run `20260929T040227Z` passed the parent-independent gate
and completed with the primary restore/verify final status `0`; the runner
reported `SUCCESS`. Its ledger contained 14 valid entries: 12 `UPDATED` and two
already-at-1.6.0 `SKIP` entries. All 14 application database catalogs were then
reported canonical at AGE 1.6.0, with graph GIN state unchanged. Independent
read-only checks recorded 35,680 documents and 35,635 `CONTAINS` relationships,
healthy API and worker graph reads, and all 14 deployments at desired, ready,
and available count 1.

The deployed wrapper and supplement SHA-256 values are respectively
`95d61b85ce9095f92d4182dba020ae8651294d9559ecd3e3b97cd7284bbf35f4` and
`af61c17fd354c424794425882dafd2d05bb6fb466a65ae98d546aa81885807c1`.
The private staging manifest used for that run had SHA-256
`fdf7f1da027864801cd387cccd7199eedf89e9284ffd9c1a19718b004970fa10`;
the raw operational bundle and manifests are intentionally not committed.
