<div align="center">

# 🎫 PayFast Tickets

**Tadbirlarga chipta bron qilish API — Unit 4 DevOps kurs loyihasi**

[English](README.md) · **O'zbekcha**

[![CI](https://github.com/Shoxjahon515/Devops/actions/workflows/ci.yml/badge.svg)](https://github.com/Shoxjahon515/Devops/actions/workflows/ci.yml)
![Python](https://img.shields.io/badge/Python-3.12-3776AB?logo=python&logoColor=white)
![FastAPI](https://img.shields.io/badge/FastAPI-0.115-009688?logo=fastapi&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-4169E1?logo=postgresql&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker&logoColor=white)
![Nginx](https://img.shields.io/badge/Nginx-1.27-009639?logo=nginx&logoColor=white)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

</div>

| | |
|---|---|
| **Muallif** | Shoxjahon Tuymurodov · 23-309 guruh · PDP University |
| **Kurs** | Unit 4 — DevOps (Pearson BTEC Level 6, Unit 70728U) |
| **O'qituvchi** | Muhammadjon Xolmirzayev (`@MuhammadjonX`) |
| **Mavzu** | 1 — Chipta bron qilish (event, seat, booking, payment, ticket) |
| **Versiya** | 1.1.0 — [CHANGELOG](CHANGELOG.md) |

Tadbirlarga chipta sotish uchun REST API. O'rindiqlar xaritasi bilan tadbir yaratiladi, o'rindiq vaqtincha band qilinadi, uning uchun to'lov aynan bir marta o'tadi (mijoz so'rovni qayta yuborsa ham) va chipta beriladi. **Ikki kishi hech qachon bitta o'rindiqni ololmaydi** — API nginx ortida bir nechta nusxada ishlasa ham. Buni ma'lumotlar bazasi kafolatlaydi va bu parallel yuklama ostida tekshirilgan.

### Asosiy imkoniyatlar

- ✅ Ikki marta bron qilish imkonsiz — partial unique index, 2 ta replikada 50 ta parallel so'rov bilan tekshirilgan
- ✅ Idempotent va qatorni qulflaydigan to'lovlar — qayta urinish hech qachon ikki marta pul yechmaydi
- ✅ Bitta buyruq bilan ishga tushadi: `make up` (yoki `docker compose up --build -d`)
- ✅ Production uslubidagi konteyner: multi-stage build, root bo'lmagan foydalanuvchi, healthcheck, gunicorn + uvicorn worker'lar
- ✅ Nginx reverse proxy: yuklamani taqsimlash va rate limit; ma'lumotlar bazasi ichki tarmoqda
- ✅ Har bir push'da CI: lint, SQLite **va** PostgreSQL'da testlar, Docker build + smoke test
- ✅ Kursning barcha haftalik DevOps vazifalari [`devops-tasks/`](devops-tasks/) papkasida

---

## Mundarija

1. [Jamoa va rollar](#1-jamoa-va-rollar)
2. [Tez ishga tushirish (Docker)](#2-tez-ishga-tushirish-docker)
3. [API](#3-api)
4. [Arxitektura](#4-arxitektura)
5. [Lokal ishlab chiqish va testlar](#5-lokal-ishlab-chiqish-va-testlar)
6. [CI](#6-ci)
7. [Ekspluatatsiya](#7-ekspluatatsiya)
8. [Repository tuzilishi](#8-repository-tuzilishi)
9. [Jamoa kelishuvi](#9-jamoa-kelishuvi)
10. [Loyiha hujjatlari](#10-loyiha-hujjatlari)
11. [DevOps kurs vazifalari](#11-devops-kurs-vazifalari)

---

## 1. Jamoa va rollar

Yakka loyiha: men biror jamoaga biriktirilmaganman, shuning uchun kursdagi beshta rolning hammasini o'zim bajaraman.

| Rol | Ushbu repodagi vazifalar | Dalil |
|---|---|---|
| Tech Lead | repository, himoyalangan `main`, yakuniy merge, o'qituvchiga kirish | branch qoidasi, `docs/access.md` |
| Product Owner / Scrum Master | issue'lar, label'lar, reja | GitHub Issues, `docs/meetings.md` |
| QA & Code Review Lead | PR shabloni, review checklist, testlar | `.github/pull_request_template.md`, `tests/` |
| DevOps / Platform Engineer | Dockerfile, Compose, nginx, CI | `Dockerfile`, `docker-compose.yml`, `.github/workflows/ci.yml` |
| Technical Writer & Security Champion | README, kirish huquqlari ro'yxati, qarorlar, maxfiy ma'lumot tekshiruvi | shu fayl, `docs/access.md`, `docs/decisions.md` |

## 2. Tez ishga tushirish (Docker)

Talab: Compose plagini bilan Docker Engine (`docker compose version`).

> Qisqa yo'l: `make up` `.env` faylini nusxalaydi va build qiladi. `make help` barcha buyruqlarni ko'rsatadi.

```bash
git clone https://github.com/Shoxjahon515/Devops.git
cd Devops
cp .env.example .env              # POSTGRES_PASSWORD ni o'zgartiring (harf va raqamlar)
docker compose up --build -d
docker compose ps                 # db, api, nginx -> healthy
curl http://localhost/health      # {"status":"ok","db":"ok",...}
```

Test interfeysi: **http://localhost/ui** — tadbir yarating, o'rinlar xaritasidan joy tanlang, bron qiling, to'lang va chiptani oling. Yuqorida API/baza holati va qaysi konteyner javob bergani ko'rinadi.

Interaktiv Swagger UI: **http://localhost/docs** (yoki `http://<VM-IP>/docs`).

> 80-port band bo'lsa, oldingi haftalardagi veb-serverlarni to'xtating: `sudo systemctl stop nginx apache2`.

### To'liq jarayonni sinab ko'rish

```bash
# 1. 2 qator x 5 o'rindiqli tadbir
curl -s -X POST http://localhost/events -H 'Content-Type: application/json' -d '{
  "title":"PDP Rock Night","venue":"PDP Hall","starts_at":"2030-05-01T19:00:00Z",
  "price":"150000","rows":2,"seats_per_row":5}'

# 2. bo'sh o'rindiqlar
curl -s "http://localhost/events/1/seats?available=true"

# 3. 1-o'rindiqni band qilish (15 daqiqaga)
curl -s -X POST http://localhost/bookings -H 'Content-Type: application/json' \
  -d '{"seat_id":1,"customer_name":"Shoxjahon Tuymurodov","customer_email":"me@example.com"}'

# 4. o'sha o'rindiq yana -> 409 Conflict
curl -s -X POST http://localhost/bookings -H 'Content-Type: application/json' \
  -d '{"seat_id":1,"customer_name":"Boshqa odam","customer_email":"x@example.com"}'

# 5. to'lov (bir xil kalit bilan qayta yuborish xavfsiz) -> chipta
curl -s -X POST http://localhost/bookings/1/pay -H 'Content-Type: application/json' \
  -H 'Idempotency-Key: order-0001-attempt' -d '{"method":"card"}'

# 6. chiptani tekshirish
curl -s http://localhost/tickets/<5-qadamdagi-code>
```

### Masshtablash va ma'lumotlarni saqlash

```bash
docker compose up -d --scale api=3
for i in 1 2 3 4 5 6; do curl -s http://localhost/; echo; done   # "host" o'zgaradi: round-robin
docker compose down && docker compose up -d                      # ma'lumot pgdata volume'da saqlanadi
docker compose down -v                                           # ma'lumotni ham o'chiradi
```

Monitoring: cAdvisor VM'ning `127.0.0.1:8080` portida. Noutbukdan: `ssh -p 2222 -L 8080:127.0.0.1:8080 <user>@<VM-IP>` → http://localhost:8080.

## 3. API

| Metod | Yo'l | Tavsif | Muvaffaqiyat | Xatolar |
|---|---|---|---|---|
| GET | `/health` | ishlash holati + bazani tekshirish | 200 | 503 baza ishlamayapti |
| GET | `/` | versiya va javob bergan konteyner | 200 | |
| POST | `/events` | tadbir + o'rindiqlar yaratish (A–Z qatorlar × qatordagi o'rindiqlar) | 201 | 422 noto'g'ri |
| GET | `/events?limit=&offset=` | bo'sh o'rindiqlar soni bilan tadbirlar ro'yxati | 200 | |
| GET | `/events/{id}` | bitta tadbir | 200 | 404 |
| GET | `/events/{id}/seats?available=true` | o'rindiqlar xaritasi | 200 | 404 |
| POST | `/bookings` | o'rindiqni band qilish | 201 | 404 o'rindiq, 409 band / tadbir boshlangan, 422 |
| GET | `/bookings/{id}` | bron holati (`pending`, `paid`, `cancelled`) | 200 | 404 |
| POST | `/bookings/{id}/cancel` | o'rindiqni bo'shatish | 200 | 409 allaqachon to'langan |
| POST | `/bookings/{id}/pay` | to'lov; `Idempotency-Key` header (8–100 belgi) | 201 chipta | 409 to'langan / bekor / muddati o'tgan, 422 kalit yo'q |
| GET | `/tickets/{code}` | chipta ma'lumotlari | 200 | 404 |

To'liq sxema: `/docs` (Swagger) va `/openapi.json`.

### Biznes qoidalari

- **Ikki marta bron yo'q.** Partial unique index har bir o'rindiq uchun faqat bitta bekor qilinmagan bronga ruxsat beradi. Buni baza ta'minlaydi, shuning uchun bir nechta replikada ham ishlaydi (ADR-003).
- **Band qilish muddati tugaydi.** To'lanmagan bron o'rindiqni `BOOKING_HOLD_MINUTES` (standart 15) daqiqa ushlab turadi, keyin o'rindiq yana bo'shaydi (ADR-005).
- **Bir marta to'lov.** Bir xil `Idempotency-Key` bilan qayta so'rov o'sha chiptani qaytaradi. Yangi kalit bilan ikkinchi to'lov `409` oladi. To'lov paytida bron qatori qulflanadi (ADR-004).
- **Validatsiya.** Narx ≥ 0, to'g'ri e-mail, to'lov usuli `card | cash | payme | click`. Boshlanib bo'lgan tadbirga bron qabul qilinmaydi.

## 4. Arxitektura

```
 mijoz ──► nginx :80 ── /bookings'da rate limit (10 r/s, burst 20) ──► api (×N, gunicorn + uvicorn worker'lar)
                                                                          │  SQLAlchemy pool, pre_ping
                                                                          ▼
                                                    PostgreSQL 16  ("backend" tarmog'i, internal: true)
                                                    pgdata volume
 cAdvisor 127.0.0.1:8080 ── konteynerlarning CPU / RAM / tarmoq ko'rsatkichlari
```

| Qatlam | Tanlov | Sababi |
|---|---|---|
| API | FastAPI, Pydantic v2 | tiplangan validatsiya, avtomatik OpenAPI hujjat |
| Ma'lumot | SQLAlchemy 2, PostgreSQL 16 | constraint va row lock'lar pul va o'rindiqlarni himoya qiladi |
| Server | gunicorn + uvicorn worker'lar | yiqilgan worker'ni qayta ishga tushiradi, bir nechta yadrodan foydalanadi |
| Proxy | nginx 1.27 | yagona kirish nuqtasi, yuklamani taqsimlash, rate limit, `server_tokens` yashirilgan |
| Image | multi-stage, `python:3.12-slim`, root bo'lmagan foydalanuvchi, healthcheck | kichik image, build vositalari yo'q, minimal huquqlar |
| Tarmoq | `frontend` + `backend` (internal) | bazaga tashqaridan ulanib bo'lmaydi |

Qarorlar va ularning sabablari: [`docs/decisions.md`](docs/decisions.md).

## 5. Lokal ishlab chiqish va testlar

```bash
python3.12 -m venv .venv && source .venv/bin/activate
pip install -r requirements-dev.txt
uvicorn app.main:app --reload            # SQLite fayli payfast.db, http://127.0.0.1:8000/ui
ruff check . && ruff format --check .
pytest -q                                # 15 ta test, xotiradagi SQLite
TEST_DATABASE_URL=postgresql+psycopg2://payfast:<parol>@localhost:5432/payfast_test pytest -q
```

Testlar quyidagilarni qamrab oladi: o'rindiqlar generatsiyasi, validatsiya, band qilish, ikki marta bron, bekor qilish, to'lov, idempotent qayta urinish, ikkinchi to'lov, to'langan bronni bekor qilib bo'lmasligi, muddat tugashi va 404 javoblar.

### Tekshirilgan natijalar

| Tekshiruv | Natija |
|---|---|
| SQLite va PostgreSQL 16 da `pytest` | ikkalasida ham 14 / 14 o'tdi |
| **bitta o'rindiqqa** **2 ta replika** orqali 50 ta parallel `POST /bookings` | aynan 1 × `201`, 49 × `409`, bazada bitta qator |
| bitta bronga turli kalitlar bilan 20 ta parallel to'lov | 1 × `201`, 19 × `409`, 1 to'lov, 1 chipta |
| 2 ta replika oldida nginx | so'rovlar replikalar orasida navbatma-navbat taqsimlanadi (round-robin) |
| nginx orqali 60 ta bron so'rovi bir zumda | rate limit ortiqchasiga `429` qaytardi |
| `ruff check .` · `docker compose config` | toza · to'g'ri |

## 6. CI

`.github/workflows/ci.yml` `main`'ga har bir push'da va har bir pull request'da ishlaydi:

1. **test** — `ruff check`, SQLite'da `pytest`, PostgreSQL 16 service konteynerida `pytest`
2. **docker** — `docker-compose.yml` ni tekshiradi, image'ni build qiladi, `db` + `api` ni ishga tushirib healthcheck'ni kutadi

Branch qoidasida "Require status checks" yoqilsa, qizil CI merge'ni bloklaydi.

## 7. Ekspluatatsiya

| Vazifa | Buyruq |
|---|---|
| Loglar | `docker compose logs -f api nginx` |
| Baza konsoli | `docker compose exec db psql -U payfast -d payfast` |
| Backup | `docker compose exec -T db pg_dump -U payfast payfast \| gzip > backup-$(date +%F).sql.gz` |
| Tiklash | `gunzip -c backup.sql.gz \| docker compose exec -T db psql -U payfast -d payfast` |
| Resurslar | `docker stats --no-stream` yoki cAdvisor |
| Yangilash | `git pull && docker compose up --build -d` |

| Belgi | Yechim |
|---|---|
| `copy .env.example to .env` xatosi | `cp .env.example .env` |
| `api` unhealthy holatida qoladi | `docker compose logs api` — odatda `.env` dagi parol noto'g'ri |
| `502 Bad Gateway` | API tayyor emas yoki yiqilgan: `docker compose ps` |
| `429 Too Many Requests` | `/bookings` dagi rate limit, keyinroq urinib ko'ring |

## 8. Repository tuzilishi

```
app/                  FastAPI ilovasi
  main.py             route'lar va xatolarni qayta ishlash
  services.py         biznes qoidalari (bron, to'lov, muddat)
  models.py           SQLAlchemy modellari va constraint'lar
  schemas.py          so'rov/javob modellari
  database.py config.py
tests/                pytest testlari
nginx/                reverse proxy sozlamalari
docs/                 kirish huquqlari, qarorlar, reja
.github/              CI workflow, Dependabot, PR va issue shablonlari
devops-tasks/         haftalik DevOps kurs vazifalari (1-5 haftalar)
Dockerfile  docker-compose.yml  Makefile  .env.example  requirements*.txt  pyproject.toml
LICENSE  CHANGELOG.md  CONTRIBUTING.md  SECURITY.md
```

## 9. Jamoa kelishuvi

- **GitHub Flow:** `main` har doim deploy qilishga tayyor. Ish har bir issue uchun alohida branch'da bo'ladi (`feature/…`, `fix/…`, `docs/…`).
- **Pull request'lar:** har bir o'zgarish shablon bo'yicha PR orqali kiradi; CI yashil bo'lishi shart; tavsifda `Closes #<issue>`.
- **Review:** 24 soat ichida. Yakka loyihada review o'qituvchi yoki kursdoshdan so'raladi.
- **Commit'lar:** buyruq shaklidagi aniq xabarlar ("Add booking expiry", "fix" emas).
- **Xavfsizlik:** Git'da maxfiy ma'lumot yo'q; `.env` faqat lokal; qarang: [`docs/access.md`](docs/access.md).

## 10. Loyiha hujjatlari

| Hujjat | Maqsadi |
|---|---|
| [CHANGELOG.md](CHANGELOG.md) | har bir versiyadagi o'zgarishlar |
| [CONTRIBUTING.md](CONTRIBUTING.md) | branch, commit va PR qoidalari |
| [SECURITY.md](SECURITY.md) | zaiflik haqida xabar berish, xavfsizlik choralari |
| [docs/decisions.md](docs/decisions.md) | arxitektura qarorlari (ADR-001 … ADR-007) |
| [docs/access.md](docs/access.md) | kimda kirish huquqi bor va nima uchun |
| [docs/meetings.md](docs/meetings.md) | reja va backlog |
| [LICENSE](LICENSE) | MIT |

## 11. DevOps kurs vazifalari

Barcha haftalik vazifalar (SSH va Apache, Linux boshqaruvi va loglar hisoboti, Bash va cron backup, Git, Docker, Docker Compose) **[`devops-tasks/`](devops-tasks/)** papkasida: har bir hafta uchun alohida papka va o'z README'si bor.

---

© 2026 Shoxjahon Tuymurodov · PDP University · o'quv loyihasi
