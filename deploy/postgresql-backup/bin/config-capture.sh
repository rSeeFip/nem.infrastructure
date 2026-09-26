#!/usr/bin/env bash

set -euo pipefail

declare -A HBA_SCANNED=()

validate_config_file() {
  local path="$1" label="$2" canonical
  [[ "$path" == /* && -f "$path" && ! -L "$path" && -r "$path" ]] || die "$label is unsafe or unreadable"
  canonical="$(realpath -e -- "$path")"
  [[ "$canonical" == "$path" ]] || die "$label is not canonical"
  [[ "$canonical" == "$CONFIG_DIR"/* ]] || die "$label escaped CONFIG_DIR"
}

materialize_config_tree() {
  local inventory="$1"
  if ! find "$CONFIG_DIR" -xdev -mindepth 1 -print0 > "$inventory"; then
    die "could not enumerate configuration tree"
  fi
}

validate_config_tree() {
  local inventory="$1" entry canonical root_device
  [[ -d "$CONFIG_DIR" && ! -L "$CONFIG_DIR" ]] || die "CONFIG_DIR must be a real directory"
  [[ "$(realpath -e -- "$CONFIG_DIR")" == "$CONFIG_DIR" ]] || die "CONFIG_DIR is not canonical"
  root_device="$(stat -c '%d' -- "$CONFIG_DIR")"
  while IFS= read -r -d '' entry; do
    [[ ! -L "$entry" ]] || die "configuration tree contains unsafe entry"
    canonical="$(realpath -e -- "$entry")"
    [[ "$canonical" == "$entry" && "$canonical" == "$CONFIG_DIR"/* ]] || die "configuration tree escaped CONFIG_DIR"
    [[ "$(stat -c '%d' -- "$entry")" == "$root_device" ]] || die "configuration tree crosses a filesystem"
    if [[ -d "$entry" ]]; then
      continue
    fi
    [[ -f "$entry" && -r "$entry" ]] || die "configuration tree contains unsafe entry"
  done < "$inventory"
}

copy_config_tree() {
  local destination="$1" inventory="$2" entry relative
  mkdir -m 700 -- "$destination"
  while IFS= read -r -d '' entry; do
    relative="${entry#"$CONFIG_DIR"/}"
    if [[ -d "$entry" ]]; then
      mkdir -m 700 -- "$destination/$relative"
    else
      install -m 600 -- "$entry" "$destination/$relative"
    fi
  done < "$inventory"
}

validate_view_files() {
  local query="$1" label="$2" inventory="$3" path raw_inventory
  : > "$inventory"
  chmod 600 -- "$inventory"
  raw_inventory="$(umask 077; mktemp --tmpdir="$(dirname -- "$inventory")" .active-files.XXXXXXXX)"
  if ! psql -XAt --dbname=postgres -c "$query" > "$raw_inventory"; then
    rm -f -- "$raw_inventory"
    die "could not enumerate $label"
  fi
  while IFS= read -r path; do
    [[ -n "$path" ]] || continue
    validate_config_file "$path" "$label"
    printf '%s\n' "${path#"$CONFIG_DIR"/}" >> "$inventory"
  done < "$raw_inventory"
  rm -f -- "$raw_inventory"
}

resolve_hba_reference() {
  local referring_file="$1" reference="$2" candidate canonical
  if [[ "$reference" == /* ]]; then
    candidate="$reference"
  else
    candidate="$(dirname -- "$referring_file")/$reference"
  fi
  canonical="$(realpath -e -- "$candidate")"
  [[ "$canonical" == "$CONFIG_DIR"/* ]] || die "HBA @file escaped CONFIG_DIR"
  validate_config_file "$canonical" "HBA @file"
  printf '%s\n' "$canonical"
}

strip_hba_comment() {
  local input="$1" output="" character
  local index quoted=0
  for ((index = 0; index < ${#input}; index++)); do
    character="${input:index:1}"
    if [[ "$character" == '"' ]]; then
      quoted=$((1 - quoted))
    elif [[ "$character" == "#" && "$quoted" == "0" ]]; then
      break
    fi
    output+="$character"
  done
  printf '%s\n' "$output"
}

scan_hba_at_files() {
  local file="$1" line remainder match reference canonical
  local -a references=()
  local pattern='(^|[[:space:],])@("[^"]+"|[^,[:space:]#]+)'
  [[ -z "${HBA_SCANNED[$file]:-}" ]] || return 0
  HBA_SCANNED["$file"]=1
  while IFS= read -r line || [[ -n "$line" ]]; do
    remainder="$(strip_hba_comment "$line")"
    while [[ "$remainder" =~ $pattern ]]; do
      match="${BASH_REMATCH[0]}"
      reference="${BASH_REMATCH[2]}"
      reference="${reference#\"}"
      reference="${reference%\"}"
      references+=("$reference")
      remainder="${remainder#*"$match"}"
    done
  done < "$file"
  for reference in "${references[@]}"; do
    canonical="$(resolve_hba_reference "$file" "$reference")"
    scan_hba_at_files "$canonical"
  done
}

validate_active_configuration() {
  local support="$1" count config_file hba_file ident_file path
  config_file="$(psql -XAt --dbname=postgres -c 'SHOW config_file')"
  hba_file="$(psql -XAt --dbname=postgres -c 'SHOW hba_file')"
  ident_file="$(psql -XAt --dbname=postgres -c 'SHOW ident_file')"
  validate_config_file "$config_file" "active configuration"
  validate_config_file "$hba_file" "active HBA configuration"
  validate_config_file "$ident_file" "active ident configuration"

  count="$(psql -XAt --dbname=postgres -c 'SELECT count(*) FROM pg_file_settings WHERE error IS NOT NULL')"
  [[ "$count" == "0" ]] || die "pg_file_settings reports errors"
  count="$(psql -XAt --dbname=postgres -c 'SELECT count(*) FROM pg_hba_file_rules WHERE error IS NOT NULL')"
  [[ "$count" == "0" ]] || die "pg_hba_file_rules reports errors"
  count="$(psql -XAt --dbname=postgres -c 'SELECT count(*) FROM pg_ident_file_mappings WHERE error IS NOT NULL')"
  [[ "$count" == "0" ]] || die "pg_ident_file_mappings reports errors"

  validate_view_files 'SELECT DISTINCT sourcefile FROM pg_file_settings WHERE sourcefile IS NOT NULL ORDER BY sourcefile' \
    "active configuration" "$support/config-files.txt"
  validate_view_files 'SELECT DISTINCT file_name FROM pg_hba_file_rules WHERE file_name IS NOT NULL ORDER BY file_name' \
    "active HBA configuration" "$support/hba-files.txt"
  validate_view_files 'SELECT DISTINCT file_name FROM pg_ident_file_mappings WHERE file_name IS NOT NULL ORDER BY file_name' \
    "active ident configuration" "$support/ident-files.txt"

  scan_hba_at_files "$hba_file"
  while IFS= read -r path; do
    [[ -n "$path" ]] || continue
    scan_hba_at_files "$CONFIG_DIR/$path"
  done < "$support/hba-files.txt"
}

capture_postgresql_config() {
  local destination="$1" support="$2" tree_inventory
  tree_inventory="$(umask 077; mktemp --tmpdir="$support" .config-tree.XXXXXXXX)"
  materialize_config_tree "$tree_inventory"
  validate_config_tree "$tree_inventory"
  validate_active_configuration "$support"
  copy_config_tree "$destination" "$tree_inventory"
  rm -f -- "$tree_inventory"
}
