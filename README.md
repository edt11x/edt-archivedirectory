# archivedirectory

A Bash script to create secure, portable, corruption-resistant archives of directories and files.

## Goals

- **Cross-platform** — archives can be extracted on Windows, macOS, and Linux
- **Encrypted at rest** — optional AES-256 GPG symmetric encryption
- **Corruption-resistant** — PAR2 forward error correction at 100% redundancy guards against bitrot
- **Widely supported tools** — `tar`, `xz`, `gpg`, and `par2` are available on all three platforms

## Dependencies

The following tools must be installed and on your `PATH`:

| Tool | Purpose |
|------|---------|
| `tar` | Archive creation |
| `xz` | Compression (maximum level, multi-threaded) |
| `gpg` | Symmetric AES-256 encryption (optional) |
| `par2` | Forward error correction |
| `perl` | Password generation for encrypted archives |

The script checks for all dependencies at startup and exits with a clear error if any are missing.

## Usage

```
archivedirectory [-b] [-d dest_dir] [-e] [-n] [-p prefix] [-h] dir_or_file_to_archive

  -b              Base64-encode the resulting archive file
  -d dest_dir     Destination directory (default: $HOME/files/backups)
  -e              Encrypt with GPG (AES-256); auto-generates a 63-char password
  -h              Display the full manual page
  -n              Run CPU-intensive processes under nice
  -p prefix       Prepend a prefix string to the archive name
```

Run `archivedirectory -h` for the full manual page including tool rationale and examples.

## What gets created

For an encrypted archive (`-e`):

```
$dest_dir/
└── {prefix}{dirname}_{hostname}_{timestamp}/
    ├── {name}.tar.xz.gpg       # compressed + encrypted archive
    ├── {name}.tar.xz.gpg.par2  # PAR2 recovery index
    ├── {name}.tar.xz.gpg.vol*.par2  # PAR2 recovery blocks
    └── README.txt              # restore instructions (relative paths)
```

For an unencrypted archive:

```
$dest_dir/
└── {prefix}{dirname}_{hostname}_{timestamp}/
    ├── {name}.tar.xz            # compressed archive
    ├── {name}.tar.xz.par2       # PAR2 recovery index
    ├── {name}.tar.xz.vol*.par2  # PAR2 recovery blocks
    └── README.txt               # restore instructions (relative paths)
```

Encrypted archives also append `archive_path password` to `$dest_dir/archive_list`. Store that file securely (e.g., in a password vault).

## Restoring an encrypted archive

```bash
gpg --decrypt archive.tar.xz.gpg | tar xpfJ -
```

## Checking integrity

```bash
par2 verify archive.tar.xz.gpg.par2
# or for unencrypted:
par2 verify archive.tar.xz.par2
```

## Periodic integrity check via cron

```bash
find /path/to/backups -type d -exec bash -c \
  'cd "{}" && par2 verify -qq *.par2 2>/dev/null' \;
```

## Examples

```bash
# Encrypted archive to default backup location
archivedirectory -e some_directory

# Encrypted archive to a specific location with a prefix
archivedirectory -d /mybackups -p project -e ./src

# Unencrypted archive with reduced CPU priority
archivedirectory -n ./large_dataset

# Encrypted + base64-encoded (for email/text transfer)
archivedirectory -b -e ./sensitive_data
```

## Notes

- The script exits immediately on any command failure (`set -e`), so a failed step never produces a silently corrupt archive.
- If the script fails mid-run, any partially created archive directory is automatically removed.
- Archive names include the source basename, hostname, and timestamp, making them unique and self-describing.
- Absolute paths and `./`-prefixed paths are both handled correctly.
- PAR2 redundancy is set to 100%, so the recovery blocks are the same size as the archive itself.
