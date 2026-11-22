# DevOps kurs vazifalari — Unit 4 (1–5 haftalar)

[English](README.md) · **O'zbekcha**

Shoxjahon Tuymurodov · 23-309 guruh · o'qituvchi: Muhammadjon Xolmirzayev

Har bir papka — bitta hafta. `RUN-ON-VM.sh` bor papkalarda Ubuntu VM'da practical'ni bajaradigan va har bir buyruqni natijasi bilan dalil sifatida (`~/weekN-evidence.txt`) saqlaydigan skript bor.

| Hafta | Mavzu | Papka | Classroom vazifasi |
|---|---|---|---|
| 1 | SSH, PuTTY, Apache2 | [`week1-ssh-apache`](week1-ssh-apache/) | Week1_Tasks |
| 2 | Linux boshqaruvi, SSH himoyasi, ufw, **loglar hisoboti** | [`week2-linux-logs-report`](week2-linux-logs-report/) | Week 2 Logs Report |
| 3 | Bash skriptlar, cron, backup | [`week3-maintain-cron-backup`](week3-maintain-cron-backup/) | Maintain (Cron & Backup) |
| 4 | Git, GitHub, pull request'lar | [`week4-git-github`](week4-git-github/) | Task 4 |
| 5 | Docker asoslari, image, GHCR | [`week5-docker-basics`](week5-docker-basics/) | Task 5 |
| 5–6 | Docker Compose'da to'liq ilova (Flask + Postgres + Nginx + cAdvisor) | [`week5-docker-compose-app`](week5-docker-compose-app/) | Creating a full working app with Docker compose |

Kurs loyihasining o'zi (chipta bron qilish API) repository'ning ildiz papkasida.

## 2-hafta qisqacha

```bash
bash RUN-ON-VM.sh           # Practical A + tarmoq tekshiruvi
bash harden-ssh.sh          # SSH -> 2222-port, faqat kalit, root'siz; kalit o'rnatilmagan bo'lsa ishlamaydi
bash harden-ssh.sh enable   # faqat 2222-portda YANGI PuTTY sessiyasi ishlagandan keyin
bash log-report.sh          # serverning haqiqiy loglaridan ~/week2-log-report.md yaratadi
```

## 3-hafta qisqacha

```bash
bash RUN-ON-VM.sh            # maintain.sh'ni o'rnatadi, barcha testlarni bajaradi, cron qo'shadi
bash RUN-ON-VM.sh collect    # 10+ daqiqadan keyin: log oxiri + 5 ta arxiv
```

`maintain.sh` `shellcheck`'dan toza o'tadi va quyidagilar uchun tekshirilgan: oddiy ishga tushish, eng yangi 5 tasini saqlash, manba papka yo'qligi, servis to'xtagani, log rotatsiyasi, tiklash, ustma-ust ishga tushish va haqiqiy cron ishga tushishlari.
