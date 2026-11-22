# Week 1 Tasks — SSH, PuTTY and the Apache2 Web Server

Unit 4 DevOps · Week 1 · Shoxjahon Tuymurodov, group 23-309

## 1. Environment

| Item | Value |
|---|---|
| Host | Windows laptop with VirtualBox and PuTTY |
| Guest | Ubuntu Server VM, 4 GB RAM, bridged network adapter |
| Access | SSH (OpenSSH server) from PuTTY, key-based login (Ed25519) |
| Web server | Apache2 serving `/var/www/html/index.html` on port 80 |

## 2. Why SSH

Servers in a data centre or cloud have no screen or keyboard, so we manage them over the network. SSH (Secure Shell) encrypts the whole session on TCP port 22, so passwords and commands cannot be read in transit (unlike Telnet or FTP). It also authenticates both sides: the client checks the server's **host key fingerprint**, the server checks the user's **password or private key**. Git, scp, Ansible and CI/CD deployments later in the course all run over SSH.

## 3. Practical A — connect to the VM

| # | Command | Purpose |
|---|---|---|
| 1 | `sudo apt update` | refresh the package list |
| 2 | `sudo apt install -y openssh-server` | install the SSH server (`sshd`) |
| 3 | `sudo systemctl enable --now ssh` | start it now **and** at every boot |
| 4 | `systemctl status ssh` | confirm `active (running)` |
| 5 | `ip addr` | find the VM's IP address for PuTTY |
| 6 | PuTTY: Host = VM IP, Port = 22, Open | first connection; accept the host key |
| 7 | `whoami · hostname · uname -a` | confirm user, machine and kernel |

**Screenshot 1:** PuTTY session after login with `whoami` and `hostname`.

### Key-based login with PuTTYgen

1. PuTTYgen → key type **Ed25519** → Generate → set a passphrase → *Save private key* (`.ppk`, stays on the laptop).
2. Copy the public key text, then on the VM:
   ```bash
   mkdir -p ~/.ssh && chmod 700 ~/.ssh
   nano ~/.ssh/authorized_keys        # paste the public key on one line
   chmod 600 ~/.ssh/authorized_keys
   ```
3. PuTTY → Connection › SSH › Auth › Credentials → select the `.ppk` → Session → Save.
4. Reconnect: login without the server password. `sudo grep "Accepted publickey" /var/log/auth.log | tail -1` proves it.

Permissions matter: `sshd` refuses keys if `~/.ssh` or `authorized_keys` is writable by others (700 / 600).

**Screenshot 2:** PuTTY Auth settings with the `.ppk` selected (the private key file itself is never shared).

## 4. Practical B — navigation, files, permissions

```bash
pwd; ls -la ~                      # where am I, what is here (incl. hidden files)
mkdir -p ~/week1 && cd ~/week1     # create and enter a folder
echo 'my first file' > notes.txt   # create a file
chmod 640 notes.txt                # owner rw, group r, others none
ls -l                              # -rw-r----- ... notes.txt
```

## 5. Apache2 web server

Apache HTTP Server is open-source software that answers HTTP/HTTPS requests on ports 80/443 with files from `/var/www/html`. It was chosen because it installs with one command, gives an instantly visible result, and practises core Linux skills: services (`apache2`), configuration (`/etc/apache2/`), logs (`/var/log/apache2/`), ports and permissions.

```bash
sudo apt install -y apache2
sudo systemctl status apache2                      # active (running)
curl http://localhost                              # default page HTML
echo "Hello from Shoxjahon Tuymurodov" | sudo tee /var/www/html/index.html
curl http://localhost                              # Hello from Shoxjahon Tuymurodov
sudo tail /var/log/apache2/access.log              # every request is logged
```

`sudo tee` is used because `sudo echo ... > file` would fail: the redirection is done by my own (non-root) shell, not by sudo.

**Screenshot 3:** Windows browser at `http://<VM-IP>` showing my page.
**Screenshot 4:** `sudo tail -n 3 /var/log/apache2/access.log` with the request from the Windows IP.

## 6. Results checklist

| Check | Result |
|---|---|
| `ssh` service active and enabled | ✔ |
| PuTTY login with password, then with key (no password asked) | ✔ |
| `apache2` service shows `active (running)` | ✔ |
| `http://<VM-IP>` in the Windows browser shows my own page | ✔ |
| My visit appears in `access.log` | ✔ |

## 7. What I learned

- A server is managed remotely; SSH gives an encrypted, authenticated channel for that.
- Key pairs are safer than passwords: only a signature travels over the network and the private key never leaves the laptop.
- `systemctl start` runs a service now, `enable` makes it start at boot.
- A web server is just a service: it has a package, a config folder, a content folder and a log — the same pattern applies to nginx, PostgreSQL or Docker later.
