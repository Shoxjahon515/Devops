# maintain.sh — automated backup, log rotation and health check

Task 3 · Unit 4 DevOps · Week 3 (Shell scripting and automation)
Author: Shoxjahon Tuymurodov, group 23-309

## What it does

`maintain.sh` is one Bash script that keeps a small server tidy. Every run it:

| Step | Function | What happens |
|---|---|---|
| 1 | `rotate_log` | If `~/logs/maintain.log` is bigger than 50 KB it is moved to `maintain.log.1` (old `.1` → `.2`, `.2` → `.3`), so the log never fills the disk. |
| 2 | `backup` | Packs `~/project-data` (or the folder given as the first argument) into `~/backups/backup-<UTC date>-<time>-<ms>.tar.gz`. |
| 3 | `prune_backups` | Keeps only the newest **5** archives and deletes older ones. |
| 4 | `check_services` | Checks that `ssh`, `cron` and `nginx` are running (`systemctl is-active`). |
| 5 | `main` | Logs `START` / `END status=N` and returns **0** if everything worked, **1** if any step failed — so cron, monitoring or a CI job can react to the exit code. |

Every action is written to `~/logs/maintain.log` with a timestamp (`OK`, `ERROR`, `FAIL`, `SKIP`).

### Safety features

- `set -euo pipefail` — stops on errors, on unset variables (typos) and on failures inside pipes.
- Every variable is quoted (`"$VAR"`), so paths with spaces work.
- A failed `tar` deletes the half-written archive instead of leaving a broken backup.
- `flock` lock file: if a run is slow, the next cron run logs `SKIP` instead of running at the same time.
- Archive names use UTC and milliseconds: two runs in the same second never overwrite each other, and the name order is always oldest → newest (prune depends on it), even if cron and your shell use different time zones.
- `shellcheck maintain.sh` reports no warnings.

## Install

```bash
mkdir -p ~/scripts ~/project-data
cp maintain.sh ~/scripts/
chmod +x ~/scripts/maintain.sh
bash -n ~/scripts/maintain.sh      # syntax check, prints nothing if OK
~/scripts/maintain.sh; echo $?     # 0 = all good
```

Run against another folder: `~/scripts/maintain.sh /srv/project`

## Schedule (cron)

Open your crontab with `crontab -e` and add **one line** (replace `student` with your user name — `echo $HOME` shows it):

```cron
*/5 * * * * /home/student/scripts/maintain.sh >> /home/student/logs/cron.log 2>&1
```

- Full paths are required: cron runs with a minimal `PATH` and no home directory context.
- `>> cron.log 2>&1` keeps both normal output and errors, so a silent failure is visible.

Check it: `crontab -l`, then after 10 minutes `tail ~/logs/maintain.log` (two `START … END` blocks) and `grep CRON /var/log/syslog | tail -5`.

### How to change the schedule

Edit the first five fields with `crontab -e`:

| Schedule | Line starts with |
|---|---|
| every 5 minutes (testing) | `*/5 * * * *` |
| every day at 02:00 | `0 2 * * *` |
| every Sunday at 03:30 | `30 3 * * 0` |
| every hour | `0 * * * *` |

Fields: minute, hour, day of month, month, day of week. To stop it, delete the line (or `crontab -r` removes the whole crontab).

## How to restore a backup

```bash
ls -1 ~/backups/                                   # newest is last
NEWEST=$(ls -1 ~/backups/backup-*.tar.gz | tail -1)
tar -tzf "$NEWEST"                                 # 1. look inside first
mkdir -p /tmp/restore
tar -xzf "$NEWEST" -C /tmp/restore                 # 2. restore to a temporary folder
ls -l /tmp/restore                                 # 3. check the files
cp -a /tmp/restore/. ~/project-data/               # 4. copy back only when you are sure
```

Restore into a temporary folder first so that a wrong archive never overwrites live data.

## Settings

Change the values at the top of the script:

| Variable | Default | Meaning |
|---|---|---|
| `SRC` | `~/project-data` | folder to back up (or pass it as `$1`) |
| `BACKUP_DIR` | `~/backups` | where archives go |
| `KEEP` | `5` | how many archives to keep |
| `MAX_LOG_BYTES` | `51200` | rotate the log above this size |
| `SERVICES` | `ssh cron nginx` | services to check |

## Tests performed

| Test | Command | Expected | Result |
|---|---|---|---|
| Normal run | `./maintain.sh; echo $?` | `0`, `END status=0` | pass |
| Keep newest 5 | `for i in {1..7}; do ./maintain.sh; sleep 1; done; ls ~/backups \| wc -l` | `5` | pass |
| Missing source | `./maintain.sh /nope; echo $?` | `1`, `ERROR source /nope not found` | pass |
| Service down | `sudo systemctl stop nginx; ./maintain.sh; echo $?` | `1`, `FAIL service nginx` | pass |
| Log rotation | `yes test \| head -n 12000 >> ~/logs/maintain.log; ./maintain.sh` | `maintain.log.1` appears | pass |
| Restore | `tar -xzf <newest> -C /tmp/r; ls /tmp/r` | `file1.txt file2.txt file3.txt` | pass |
| Overlapping run | second run while the first holds the lock | `SKIP …`, exit 1 | pass |
| Quality | `shellcheck maintain.sh` | no output | pass |

## Security note

No password or token is stored in this script or in this repository. Backups can contain sensitive data: keep `~/backups` readable only by its owner (`chmod 700 ~/backups`).
