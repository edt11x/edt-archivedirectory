# archivedirectory — Claude context

## What this project is

A single-file Bash script (`archivedirectory`) that creates secure, portable,
corruption-resistant archives. It combines `tar` + `xz` + `gpg` + `par2` into
one workflow. The embedded manual page (`-h`) is the authoritative reference.

## Session history (2026-05-05)

A full code review was performed. All medium and cosmetic issues were fixed,
plus two high-priority issues. Summary of changes made:

### Fixed
- **Dependency pre-check** — `check_deps()` runs at startup; exits with a clear
  list of any missing tools (`tar`, `xz`, `gpg`, `par2`, `perl`).
- **Cleanup trap** — `trap cleanup ERR` removes `ARCHIVE_TO_DIR` on failure so
  partial archive directories are never left behind.
- **Argument loop comparison bug** — `[[ $# > 1 ]]` (string compare) replaced
  with `(( $# > 1 ))` (integer compare).
- **`$NICE` consistency** — added to unencrypted `par2 create`, `par2 verify`,
  and the encrypted archive verification `gpg` call.
- **`die` no longer dumps usage** — `die` just prints the error and exits.
  A new `die_usage` function handles the two argument-validation sites that
  should show the usage synopsis.
- **Absolute path handling** — `ARCHIVE_DIRNAME=$(basename "$ARCHIVE_FROM")`
  prevents slashes in archive names when an absolute path is passed.
- **Removed double `export HOSTNAME`** and stripped unnecessary `export` from
  all internal variables.
- **Removed redundant final `pushd`** at end of script.
- **Removed redundant `set +x`** inside the encrypt branch after the README
  heredoc.
- **README.txt uses relative paths** — `${ARCHIVE_GPG##*/}` instead of the
  full absolute path, so restore commands stay correct if the archive is moved.
- **`-h` exits 0** — `show_manual` (was `man`) now exits with code 0.
- **`man` renamed to `show_manual`** — the previous name shadowed the system
  `man` command.
- **Password no longer in `set -x` trace** — `set +x` is now active for all
  three password-touching operations: `gpg --symmetric`, the `archive_list`
  write, and `gpg --decrypt` verification. `set -x` is only active for `par2`.
- **Help text updated** — `-h` option added to SYNOPSIS and options list.

### Known remaining issue
- **Plaintext `archive_list`** — `$dest_dir/archive_list` stores
  `archive_path password` in cleartext. Anyone with read access to the backup
  directory can read all passwords. Mitigation: restrict permissions on the
  backup directory, or encrypt `archive_list` itself (e.g., with GPG). This
  is a design trade-off — the list exists so passwords survive if the encrypted
  archive metadata is lost.

## Code conventions

- Single-file Bash script; no build system.
- `set -e` throughout — every command must succeed or the script aborts.
- `set -x` is used only for the `par2` commands to show progress without
  exposing passwords.
- Internal variables are plain (no `export`); only `HOSTNAME` is exported
  because it is a bash special variable.
- Functions defined at the top: `die`, `die_usage`, `usage`, `show_manual`,
  `check_deps`, `cleanup`.

## Testing

There is no automated test suite. Manual testing steps:

1. **Unencrypted**: `archivedirectory /tmp/some_dir` — verify archive + par2
   files created, README.txt contains relative paths, `par2 verify` passes.
2. **Encrypted**: `archivedirectory -e /tmp/some_dir` — verify `.gpg` file,
   par2 files, password printed (not in trace), `archive_list` updated.
3. **Missing tool**: remove `par2` from PATH, run script — should exit with
   "Missing required tools: par2".
4. **Failure cleanup**: cause a mid-run failure (e.g., bad dest path) — verify
   no partial directory is left behind.
5. **Absolute path**: `archivedirectory -e /home/user/mydir` — verify archive
   name is `mydir_host_date`, not `/home/user/mydir_host_date`.
