#!/usr/bin/env bash
set -euo pipefail

root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
wrapper="$root/apply-age-1.6-catalog-parity.sql"
repair="$root/age-1.6-catalog-parity-repair.sql"

fail() {
    printf 'static check failed: %s\n' "$*" >&2
    exit 1
}

require_literal() {
    local file=$1
    local literal=$2
    grep -Fq -- "$literal" "$file" || fail "missing '$literal' in ${file##*/}"
}

reject_regex() {
    local regex=$1
    if grep -Eiq -- "$regex" "$wrapper" "$repair"; then
        fail "prohibited SQL matched: $regex"
    fi
}

[[ $(<"$root/VERSION") == age-1.5.0-to-1.6.0-catalog-parity-local-v1 ]] \
    || fail 'unexpected repair version'
[[ ! -e "$root/age--1.5.0--1.6.0.sql" ]] || fail 'vendor update must not be vendored'

require_literal "$wrapper" "BEGIN;"
require_literal "$wrapper" "ALTER EXTENSION age UPDATE TO '1.6.0';"
require_literal "$wrapper" '\ir age-1.6-catalog-parity-repair.sql'
require_literal "$wrapper" "COMMIT;"
require_literal "$repair" "'age_catalog_repair.official_upgrade'"
require_literal "$repair" "actual.oprcode <> 0"
require_literal "$repair" "dependent_count <> 0"
require_literal "$repair" "SET LOCAL ROLE %I"
require_literal "$repair" "AS '\$libdir/age';"

[[ $(grep -Ec '^ALTER EXTENSION age DROP (FUNCTION|OPERATOR)' "$repair") -eq 5 ]] \
    || fail 'expected five guarded extension-member removals'
[[ $(grep -Ec '^DROP (FUNCTION|OPERATOR).* RESTRICT;' "$repair") -eq 5 ]] \
    || fail 'expected five RESTRICT drops'
[[ $(grep -Ec '^ALTER EXTENSION age ADD (FUNCTION|CAST)' "$repair") -eq 5 ]] \
    || fail 'expected five explicit extension-member additions'
[[ $(grep -Fc "AS '\$libdir/age';" "$repair") -eq 4 ]] \
    || fail 'expected four explicit AGE library mappings'

reject_regex 'MODULE_PATHNAME'
reject_regex 'DROP[[:space:]]+(EXTENSION|SCHEMA|TABLE)'
reject_regex 'DROP[^;]*CASCADE'
reject_regex 'UPDATE[[:space:]]+pg_catalog'
reject_regex '(^|[[:space:]])GRANT[[:space:]]'
reject_regex 'ALTER[[:space:]].*OWNER[[:space:]]+TO'

(cd "$root" && sha256sum --check MANIFEST.sha256)

if [[ -n ${AGE_UPSTREAM_SOURCE:-} ]]; then
    [[ $(sha256sum "$AGE_UPSTREAM_SOURCE/age--1.5.0--1.6.0.sql" | cut -d' ' -f1) == \
        44b6c775d880530e6c50937966ff879701a614d194dfcf99ec3d6e3f959c6f9f ]] \
        || fail 'official update SHA-256 mismatch'
    [[ $(sha256sum "$AGE_UPSTREAM_SOURCE/sql/agtype_coercions.sql" | cut -d' ' -f1) == \
        9c41ecdf8f6c5b92971714e25abe3dc44ef6a0db436e0d74ed340cbf17a042ee ]] \
        || fail 'agtype_coercions.sql SHA-256 mismatch'
    [[ $(sha256sum "$AGE_UPSTREAM_SOURCE/sql/age_main.sql" | cut -d' ' -f1) == \
        543077146a4ef0fb6f9f719c59167ebe0197fb026a0d1c99aab4489989716ab7 ]] \
        || fail 'age_main.sql SHA-256 mismatch'
fi

printf 'AGE catalog repair static checks passed\n'
