# Contributing

Thanks for helping improve PayFast Tickets.

## Workflow (GitHub Flow)

1. Open or pick an issue.
2. Create a branch from `main`: `feature/<short-name>`, `fix/<short-name>` or `docs/<short-name>`.
3. Make small, focused commits with imperative messages: `Add booking expiry`, not `fixed stuff`.
4. Before pushing:
   ```bash
   make lint
   make test
   ```
5. Open a pull request using the template, link the issue with `Closes #<n>`.
6. CI must be green and one reviewer must approve before merging. Use **Squash and merge** for single-purpose PRs.

## Code style

- Python 3.12, type hints, `ruff` for linting and formatting (config in `pyproject.toml`).
- Business rules belong in `app/services.py`; `app/main.py` only maps HTTP to services.
- Every new rule gets a test in `tests/`.
- Expected failures return clear HTTP errors (`404`, `409`, `422`), never `500`.

## Security

Never commit `.env`, passwords, tokens or keys. See [SECURITY.md](SECURITY.md).
