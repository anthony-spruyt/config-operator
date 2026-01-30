# Renovate Throttling Design

## Problem

The `container-images` repository consumed all 2000 free GitHub Actions minutes in a month due to frequent Renovate PRs. Each PR triggers CI which builds Docker images (expensive).

Main offenders:

- `renovate` npm package: 10+ updates in 5 days
- GitHub Actions digest updates (`docker/login-action`, `actions/attest-build-provenance`): 8+ updates in 5 days
- Various other high-frequency packages

## Solution

Two-tier approach:

1. **Global conservative defaults** - Throttle high-frequency packages for all repos
2. **Container-images aggressive throttling** - Batch all non-major updates weekly

## Design

### Global Changes

Add to `.github/renovate/package-rules.json5`:

```json5
{
  description: "Limit GitHub Actions digest updates to weekly and group them",
  matchManagers: ["github-actions"],
  matchUpdateTypes: ["digest"],
  schedule: ["before 9am on monday"],
  groupName: "github-actions-digest",
  group: { commitMessageTopic: "GitHub Actions digest updates" },
}
```

This complements the existing renovate CLI weekly rule.

### Container-Images Specific

Add to `.github/renovate/package-rules.json5` using `matchRepositories`:

```json5
{
  description: "Weekly batch for all non-major updates in container-images",
  matchRepositories: ["anthony-spruyt/container-images"],
  matchUpdateTypes: ["minor", "patch", "digest", "pin", "pinDigest"],
  schedule: ["before 9am on monday"],
  groupName: "weekly-dependencies",
  group: { commitMessageTopic: "weekly dependency updates" },
}
```

This is cleaner than xfg override since package-rules.json5 is centralized in repo-operator and referenced by all repos via `github>anthony-spruyt/repo-operator//...`.

## Expected Impact

| Metric                      | Before | After |
| --------------------------- | ------ | ----- |
| container-images PRs/week   | ~20-30 | ~1-3  |
| Other repos digest PRs/week | ~5-10  | ~1    |

## Implementation Steps

1. Edit `.github/renovate/package-rules.json5` - add GitHub Actions digest rule
2. Edit `.github/renovate/package-rules.json5` - add container-images `matchRepositories` rule
3. Commit and push
4. Renovate picks up changes on next run (no xfg sync needed - repos reference this config directly)
5. Verify Renovate Dashboard shows new schedule
