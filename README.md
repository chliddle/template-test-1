# template-test-1

The [local-platform-lab](https://github.com/chliddle/local-platform-lab)
platform's example/test app -- generated from the
[local-platform-lab-app-template](https://github.com/chliddle/local-platform-lab-app-template)
template repo (its `template-init` workflow renamed everything
automatically on first push). This repo owns its own app code, tests,
container build, semantic versioning, and deployment manifests end to
end; the platform repo only holds an `Application` pointer at it and is
never touched for routine releases.

## What's here

- `main.go`, `internal/` -- the app itself (a small Go HTTP service:
  `/`, `/health`, `/ready`, `/version`, `/metrics`)
- `Dockerfile` -- multi-arch (amd64/arm64) build, cross-compiled to avoid
  QEMU emulation
- `deploy/base/` -- Kustomize base (Deployment, Service)
- `deploy/overlays/dev/`, `deploy/overlays/prod/` -- per-environment
  overlays; `images:` here is the pinned digest Argo CD deploys
- `scripts/smoke-test.sh` -- asserts the platform's app contract (the 5
  endpoints above)
- `.github/workflows/ci.yml` -- lint, test, ephemeral-cluster smoke test,
  build, push to GHCR, patch the digest into `deploy/overlays/dev`
- `.github/workflows/release.yml` -- runs after `ci.yml` succeeds;
  semantic-release cuts a version from Conventional Commits, then promotes
  the *same* GHCR digest (never rebuilt) into `deploy/overlays/prod`
- `.github/workflows/template-init.yml` -- already ran once (see
  `.github/.template-initialized`); a permanent no-op from here on

## The pipeline

```
push to main (feat:/fix:/...)
  -> ci: lint, test, ephemeral-cluster smoke test, build multi-arch image,
     push to GHCR (tag: commit SHA)
  -> ci: patch deploy/overlays/dev with the resulting digest, commit
  -> release (gated on ci succeeding): semantic-release computes next version
       - if a release is warranted:
           -> re-tag the same GHCR digest with the semver (no rebuild)
           -> patch deploy/overlays/prod with the same digest, commit
  -> Argo CD (running in the platform repo's dev/prod clusters) reconciles
     both overlays automatically
```

No manual approval gate: trunk-based development wants small changes to
ship often, and a human-in-the-loop step just creates a queue. The
promotion gate is `ci.yml` passing -- lint/test/ephemeral-cluster smoke
test -- not yet a live canary/rollout health check (that arrives with
Argo Rollouts, Milestone 6 in the platform repo).

**Commit messages on `main` must follow [Conventional Commits](https://www.conventionalcommits.org/)**
(`feat:`, `fix:`, `chore:`, ...) or `release.yml` never cuts a version.

## Local development

```bash
make build   # go build
make test    # go test ./...
make run     # build + run on :8080
```

```bash
docker build -t template-test-1:local .
docker run -p 8080:8080 -e ENVIRONMENT=local template-test-1:local
```

**`FAULT_ERROR_RATE`** (float, `0.0`-`1.0`, default `0`, read once at
startup): injects a synthetic `500` on `/` at this rate --
`internal/middleware/fault.go`. `/health`/`/ready`/`/version` are never
affected, deliberately: this simulates a bad deploy that passes every
health check but serves broken responses to real traffic, exactly the
class of bug canary analysis / blue-green manual gates exist to catch. The
platform repo's `dev-rolling`/`dev-bluegreen`/`dev-canary` overlays
(Milestone 6) deploy this app three ways in parallel specifically to
compare how each strategy handles this same injected fault --
`scripts/simulate-bad-rollout.sh` in the platform repo drives it.

## Pre-commit hooks

[gitleaks](https://github.com/gitleaks/gitleaks) scans every commit for
hardcoded secrets before it's made. [zizmor](https://github.com/zizmorcore/zizmor)
scans every workflow change for dangerous GitHub Actions patterns -- the
same check also runs as a CI job (`security lint`), with online audits
enabled there. **Not** a required status check here specifically: this
repo's own automation (`ci.yml`'s digest-bump commit, `release.yml`'s
prod promotion, `template-init.yml`) pushes bot-authored commits
directly to `main`, and GitHub rejects any direct push whose commit
hasn't already had a required check run against it -- which a
just-created commit never has. Required on the platform repo
(`local-platform-lab`), which has no such automation.

```bash
brew install pre-commit   # or: pip install pre-commit
pre-commit install        # once per clone -- wires the hook into .git/hooks/
```

## License

[MIT](LICENSE)
