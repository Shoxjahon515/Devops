# Access register

Who can do what in this repository and why (Technical Writer & Security Champion role).

| Person | GitHub | Role | Permission | Why |
|---|---|---|---|---|
| Shoxjahon Tuymurodov | `Shoxjahon515` | Owner · all five project roles | Admin | solo project, repository owner |
| Muhammadjon Xolmirzayev (teacher) | `MuhammadjonX` | Reviewer / auditor | Read (or Write if reviews are required) | course assessment |

## Rules

- `main` is protected: changes come through pull requests; CI (`ruff`, `pytest`, Docker build) must pass.
- No passwords, tokens, private keys or `.env` files in the repository. `.gitignore` blocks `.env`, `*.pem`, `*.ppk`, `id_*`.
- Local secrets live in `.env` (copied from `.env.example`), mode 600.
- Access is reviewed when someone joins or leaves; removing a collaborator is the first step when a person leaves.

## Secret check before every push

```bash
git ls-files | grep -Ei '\.env$|\.pem$|\.ppk$|id_rsa|id_ed25519' && echo "STOP: secret file tracked"
git grep -nEi '(password|secret|token)\s*=\s*[^$ {]' -- ':!*.md' ':!.env.example' ':!.github/*'
```
