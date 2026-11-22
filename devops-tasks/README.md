# DevOps course tasks — Unit 4 (Weeks 1–5)

**English** · [O'zbekcha](README.uz.md)

Shoxjahon Tuymurodov · group 23-309 · teacher: Muhammadjon Xolmirzayev

Each folder is one week. Folders with a `RUN-ON-VM.sh` contain a script that runs the practical on the Ubuntu VM and saves every command with its output as evidence (`~/weekN-evidence.txt`).

| Week | Topic | Folder | Classroom assignment |
|---|---|---|---|
| 1 | SSH, PuTTY, Apache2 | [`week1-ssh-apache`](week1-ssh-apache/) | Week1_Tasks |
| 2 | Linux administration, SSH hardening, ufw, **logs report** | [`week2-linux-logs-report`](week2-linux-logs-report/) | Week 2 Logs Report |
| 3 | Bash scripting, cron, backups | [`week3-maintain-cron-backup`](week3-maintain-cron-backup/) | Maintain (Cron & Backup) |
| 4 | Git, GitHub, pull requests | [`week4-git-github`](week4-git-github/) | Task 4 |
| 5 | Docker basics, image, GHCR | [`week5-docker-basics`](week5-docker-basics/) | Task 5 |
| 5–6 | Full app with Docker Compose (Flask + Postgres + Nginx + cAdvisor) | [`week5-docker-compose-app`](week5-docker-compose-app/) | Creating a full working app with Docker compose |

The course project itself (ticket booking API) is in the root of this repository.

## Week 2 in short

```bash
bash RUN-ON-VM.sh        # Practical A + network checks
bash harden-ssh.sh       # SSH -> port 2222, keys only, no root; refuses if no key is installed
bash harden-ssh.sh enable   # only after a NEW PuTTY session on 2222 works
bash log-report.sh       # writes ~/week2-log-report.md from the server's real logs
```

## Week 3 in short

```bash
bash RUN-ON-VM.sh            # install maintain.sh, run all tests, add the cron job
bash RUN-ON-VM.sh collect    # 10+ minutes later: tail of the log + 5 archives
```

`maintain.sh` passes `shellcheck` and was tested for: normal run, keep-newest-5, missing source, service down, log rotation, restore, overlapping runs and real cron runs.
