# Week 2 — Task 2: Linux Administration, Server Hardening and Logs Report

Unit 4 DevOps · Week 2 · Shoxjahon Tuymurodov, group 23-309

The full log investigation is in `week2-log-report.md` (generated from the server's real logs by `log-report.sh`). This document is the command log and explanation required by Task 2.

## Evidence index

| # | Evidence | Where |
|---|---|---|
| 1 | Screenshot: `id alice` and `ls -ld /srv/project` | screenshot 1 |
| 2 | Screenshot: `systemctl status nginx` | screenshot 2 |
| 3 | Output: `sudo sshd -T` showing `port 2222` and `passwordauthentication no` | section B5 / `week2-evidence.txt` |
| 4 | Output: `sudo ufw status numbered` | section B6 / `week2-evidence.txt` |
| 5 | Screenshot: refused login without a key | screenshot 3 |
| 6 | Command log: each command, purpose, why it matters | this document + `week2-evidence.txt` |

## Practical A — Linux administration

| Step | Command | Purpose | Why it matters |
|---|---|---|---|
| A1 | `sudo adduser alice` · `sudo adduser bob` | create two accounts | each person has their own identity in the logs |
| A1 | `sudo groupadd devteam` | create a team group | access is given to a role, not person by person |
| A1 | `sudo usermod -aG devteam alice` | add to the group | `-a` appends; without it `-G` removes all other groups |
| A1 | `id alice` · `getent group devteam` | verify | never assume a change worked |
| A2 | `sudo mkdir /srv/project` | shared folder | `/srv` = data served by this machine |
| A2 | `sudo chown root:devteam /srv/project` | owner and group | the group decides who may work there |
| A2 | `sudo chmod 2770 /srv/project` | rwx for owner + group, nothing for others, setgid | setgid (`2`) makes every new file inherit `devteam` |
| A2 | `sudo -u alice touch /srv/project/a.txt` | test as a member | works |
| A2 | `ls /srv/project` | test as a non-member | **Permission denied** — least privilege works |
| A3 | `./hello.sh` → `chmod u+x hello.sh` | execute bit | a file runs only with `x`; first run is denied |
| A3 | `chmod 640 notes.txt` | owner rw, group r | `-rw-r-----` |
| A4 | `sudo apt update` / `apt install -y htop tree` / `apt remove tree` | package management | `update` refreshes the list, it never changes software; `upgrade` does |
| A5 | `systemctl status/stop/start/is-enabled nginx` | service control | `start` = now, `enable` = at boot |
| A6 | `journalctl -u ssh -n 20` · `sudo tail /var/log/auth.log` | read logs | my own `Accepted publickey` line proves key login |
| A7 | `sleep 600 &` · `pgrep -a sleep` · `pkill sleep` | processes | `kill` sends TERM (clean stop); `-9` only as a last resort |

## Practical B — network, SSH and firewall hardening

**B1 Network diagnosis** (inside out): `ip -br a` (address) → `ip route` (default gateway) → `resolvectl status` (DNS) → `ping -c 3 8.8.8.8` (internet; campus networks may block ICMP, so confirm with `curl -I http://example.com`) → `curl -I localhost` (service).

**B2 Listening ports** — `sudo ss -tulpn`:

| Port | Process | Bound to | Decision |
|---|---|---|---|
| 22 → 2222 | sshd | 0.0.0.0 | needed for administration → allow 2222 only |
| 80 | nginx | 0.0.0.0 | public web service → allow |
| 53 | systemd-resolved | 127.0.0.53 | local DNS cache, not reachable from outside → nothing to do |

**B3 Firewall rules first (ufw still inactive)**

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 2222/tcp comment 'SSH'
sudo ufw allow 80/tcp comment 'HTTP'
sudo ufw show added
```

Port 22 is deliberately not allowed — SSH moves to 2222.

**B4–B5 SSH hardening** — drop-in file `/etc/ssh/sshd_config.d/01-hardening.conf`:

```
Port 2222
PasswordAuthentication no
PermitRootLogin no
PermitEmptyPasswords no
MaxAuthTries 3
LoginGraceTime 30
X11Forwarding no
```

Safe procedure: back up `sshd_config` → write the drop-in → `sudo sshd -t` (no output = valid) → `sudo systemctl restart ssh` → log in on **2222 in a new window** → only then close the old session. The file name starts with `01-` because sshd uses the **first** value it reads, so it wins over later files such as cloud-init's.

```
$ sudo sshd -T | grep -Ei "^(port|passwordauthentication|permitrootlogin)"
port 2222
permitrootlogin no
passwordauthentication no
```

**B6 Test, then enable the firewall**

```
$ sudo ufw enable
$ sudo ufw status numbered
     To                         Action      From
     --                         ------      ----
[ 1] 2222/tcp                   ALLOW IN    Anywhere                   # SSH
[ 2] 80/tcp                     ALLOW IN    Anywhere                   # HTTP
[ 3] 2222/tcp (v6)              ALLOW IN    Anywhere (v6)              # SSH
[ 4] 80/tcp (v6)                ALLOW IN    Anywhere (v6)              # HTTP
```

From Windows: `curl.exe -I http://<VM-IP>` → `200 OK`; `Test-NetConnection <VM-IP> -Port 2222` → `True`; `-Port 22` → `False`; PuTTY without a key → *No supported authentication methods available* (screenshot 3).

*(The outputs above show the expected format; the exact outputs from my VM are in `week2-evidence.txt`.)*

## Exit questions

1. **What does `chmod 750` mean?** Owner `rwx` (7 = 4+2+1): read, write, execute. Group `r-x` (5 = 4+1): read and execute. Others `---` (0): no access. Result: `-rwxr-x---`.
2. **`systemctl start` vs `enable`?** `start` runs the service now but not after a reboot; `enable` creates the boot link so it starts at every boot but does not start it now. They are independent — `enable --now` does both.
3. **Why open 2222 in ufw before enabling the firewall?** With `default deny incoming`, enabling ufw first would block every new SSH connection; my current session might survive, but I could never log in again (lock-out). Rules first, firewall second.
4. **Why test the new SSH login before closing the old session?** If the new configuration is wrong (typo, wrong port, key not accepted), the old session is the only way back in to fix it — without it I would need the VirtualBox console or a snapshot restore.

## Conclusion

The server now follows least privilege (separate users, group-owned shared folder, correct modes), runs only the needed services, accepts SSH only with keys on port 2222 without root login, and blocks everything else with ufw. The logs report confirms these controls and shows that every login and administrative action is traceable.
