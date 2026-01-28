# Renovate Configuration Consolidation Design

## Overview

Consolidate Renovate configurations from multiple repositories into a single, modular config managed by repo-operator and synced via xfg.

## Current State

6 repos have Renovate configs with varying features:

| Repo                              | Key Differences                                             |
| --------------------------------- | ----------------------------------------------------------- |
| xfg, repo-operator, claude-config | Standard config (shell script regex managers)               |
| container-images                  | + flavor.yaml and metadata.yaml custom managers             |
| SunGather                         | + pip_requirements manager                                  |
| spruyt-labs                       | Kubernetes/Flux/Terraform/Helm focused, modular sub-configs |

10 repos have no Renovate config.

## Goals

- Single source of truth for Renovate configuration
- Modular structure for maintainability
- Per-repo overrides via xfg where needed
- Remove `createOnly: true` to always sync

## Design

### File Structure

```
src/templates/.github/
├── renovate.json5                          # Main config (extends modules)
└── renovate/
    ├── base.json5                          # Core settings
    ├── managers.json5                      # enabledManagers + file patterns
    ├── custom-managers/
    │   ├── annotated.json5                 # Generic annotation-based patterns
    │   └── infrastructure.json5            # K8s/Flux/Helm structure-based patterns
    ├── package-rules.json5                 # Labels, commit messages
    ├── groups.json5                        # Package groupings
    ├── automerge.json5                     # Automerge rules
    ├── custom-datasources.json5            # Custom datasources
    └── disabled.json5                      # Disabled datasources/packages
```

### Module Contents

#### renovate.json5 (main)

```json5
{
  $schema: "https://docs.renovatebot.com/renovate-schema.json",
  extends: [
    "local>.github/renovate/base.json5",
    "local>.github/renovate/managers.json5",
    "local>.github/renovate/custom-managers/annotated.json5",
    "local>.github/renovate/custom-managers/infrastructure.json5",
    "local>.github/renovate/package-rules.json5",
    "local>.github/renovate/groups.json5",
    "local>.github/renovate/automerge.json5",
    "local>.github/renovate/custom-datasources.json5",
    "local>.github/renovate/disabled.json5",
  ],
}
```

#### base.json5

```json5
{
  $schema: "https://docs.renovatebot.com/renovate-schema.json",
  extends: [
    "config:recommended",
    "docker:enableMajor",
    ":dependencyDashboard",
    ":disableRateLimiting",
    ":semanticCommits",
    ":enablePreCommit",
    ":separatePatchReleases",
  ],
  enabled: true,
  dependencyDashboardTitle: "Renovate Dashboard",
  suppressNotifications: ["prIgnoreNotification"],
  commitBodyTable: true,
  rebaseWhen: "behind-base-branch",
}
```

#### managers.json5

```json5
{
  $schema: "https://docs.renovatebot.com/renovate-schema.json",
  enabledManagers: [
    "custom.regex",
    "devcontainer",
    "dockerfile",
    "flux",
    "github-actions",
    "helm-values",
    "kubernetes",
    "npm",
    "pip_requirements",
    "pre-commit",
    "terraform",
  ],
  devcontainer: {
    managerFilePatterns: ["/\\.?devcontainer\\.json$/"],
  },
  flux: {
    managerFilePatterns: ["/(^|/)cluster/.+\\.ya?ml$/"],
  },
  "helm-values": {
    managerFilePatterns: [
      "/(^|/)cluster/.+/(values(\\.\\w+)?|values\\.ya?ml)$/",
      "/(^|/)cluster/.+/(release|helmrelease)\\.ya?ml$/",
    ],
  },
  kubernetes: {
    managerFilePatterns: [
      "/(^|/)cluster/.+\\.ya?ml$/",
      "/(^|/)talos/.+\\.ya?ml$/",
    ],
  },
  terraform: {
    managerFilePatterns: [
      "/\\.tf$/",
      "/\\.tfvars/",
      "/\\.terraform\\.lock\\.hcl$/",
    ],
  },
}
```

#### custom-managers/annotated.json5

Generic annotation-based patterns for `# renovate:` comments:

```json5
{
  $schema: "https://docs.renovatebot.com/renovate-schema.json",
  customManagers: [
    // Shell scripts: VAR="version"
    {
      customType: "regex",
      description: ["Annotated shell variable (depName first)."],
      managerFilePatterns: ["/\\.(sh|bash)$/"],
      matchStrings: [
        'depName=(?<depName>\\S+) datasource=(?<datasource>\\S+)(?:\\s+versioning=(?<versioning>\\S+))?\\n(?:export\\s+)?[A-Z_]+="(?<currentValue>v?[^"]+)"',
      ],
      datasourceTemplate: "{{#if datasource}}{{{datasource}}}{{else}}github-releases{{/if}}",
      versioningTemplate: "{{#if versioning}}{{{versioning}}}{{else}}semver{{/if}}",
    },
    {
      customType: "regex",
      description: ["Annotated shell variable (datasource first)."],
      managerFilePatterns: ["/\\.(sh|bash)$/"],
      matchStrings: [
        'datasource=(?<datasource>\\S+) depName=(?<depName>\\S+)(?:\\s+versioning=(?<versioning>\\S+))?\\n(?:export\\s+)?[A-Z_]+="(?<currentValue>v?[^"]+)"',
      ],
      datasourceTemplate: "{{#if datasource}}{{{datasource}}}{{else}}github-releases{{/if}}",
      versioningTemplate: "{{#if versioning}}{{{versioning}}}{{else}}semver{{/if}}",
    },
    // YAML: version/key field
    {
      customType: "regex",
      description: ["Annotated YAML field (depName first)."],
      managerFilePatterns: ["/\\.ya?ml$/"],
      matchStrings: [
        '#\\s*renovate:\\s*depName=(?<depName>\\S+)\\s+datasource=(?<datasource>\\S+)(?:\\s+versioning=(?<versioning>\\S+))?\\n\\s*\\w+:\\s*"?(?<currentValue>[^"\\s]+)"?',
      ],
      datasourceTemplate: "{{#if datasource}}{{{datasource}}}{{else}}github-tags{{/if}}",
      versioningTemplate: "{{#if versioning}}{{{versioning}}}{{else}}semver{{/if}}",
    },
    {
      customType: "regex",
      description: ["Annotated YAML field (datasource first)."],
      managerFilePatterns: ["/\\.ya?ml$/"],
      matchStrings: [
        '#\\s*renovate:\\s*datasource=(?<datasource>\\S+)\\s+depName=(?<depName>\\S+)(?:\\s+versioning=(?<versioning>\\S+))?\\n\\s*\\w+:\\s*"?(?<currentValue>[^"\\s]+)"?',
      ],
      datasourceTemplate: "{{#if datasource}}{{{datasource}}}{{else}}github-tags{{/if}}",
      versioningTemplate: "{{#if versioning}}{{{versioning}}}{{else}}semver{{/if}}",
    },
    // YAML: Docker image with optional digest
    {
      customType: "regex",
      description: ["Annotated Docker image (depName first)."],
      managerFilePatterns: ["/\\.ya?ml$/"],
      matchStrings: [
        '#\\s*renovate:\\s*depName=(?<depName>\\S+)\\s+datasource=docker\\n\\s*\\w+:\\s*"[^:]+:(?<currentValue>[^@"]+)(?:@(?<currentDigest>sha256:[^"]+))?"',
      ],
      datasourceTemplate: "docker",
      versioningTemplate: "docker",
    },
    {
      customType: "regex",
      description: ["Annotated Docker image (datasource first)."],
      managerFilePatterns: ["/\\.ya?ml$/"],
      matchStrings: [
        '#\\s*renovate:\\s*datasource=docker\\s+depName=(?<depName>\\S+)\\n\\s*\\w+:\\s*"[^:]+:(?<currentValue>[^@"]+)(?:@(?<currentDigest>sha256:[^"]+))?"',
      ],
      datasourceTemplate: "docker",
      versioningTemplate: "docker",
    },
  ],
}
```

#### custom-managers/infrastructure.json5

Structure-based patterns for Kubernetes/Flux/Helm:

```json5
{
  $schema: "https://docs.renovatebot.com/renovate-schema.json",
  customManagers: [
    // Headlamp plugins from ArtifactHub
    {
      customType: "regex",
      description: ["Headlamp plugins from ArtifactHub."],
      managerFilePatterns: ["/(^|/)cluster/apps/headlamp-system/.+\\.ya?ml$/"],
      matchStrings: [
        "#\\s*renovate:\\s*depName=(?<depName>[^\\s]+)[\\s\\S]*?version:\\s*(?<currentValue>\\d[^\\s]*)",
      ],
      datasourceTemplate: "custom.artifacthub-headlamp",
    },
    // OCI Helm charts in helmfile
    {
      customType: "regex",
      description: ["OCI Helm charts in Talos helmfile."],
      managerFilePatterns: ["/(^|/)talos/helmfile/.+\\.ya?ml$/"],
      matchStrings: [
        "chart:\\s*oci://(?<chartPath>[\\w./-]+)\\s*\\n[^\\S\\n]*version:\\s*(?<currentValue>[^\\s\"']+)",
      ],
      depNameTemplate: "{{{chartPath}}}",
      datasourceTemplate: "docker",
      packageNameTemplate: "{{{chartPath}}}",
    },
    // Non-OCI Helm charts in helmfile
    {
      customType: "regex",
      description: ["Non-OCI Helm charts in Talos helmfile."],
      managerFilePatterns: ["/(^|/)talos/helmfile/.+\\.ya?ml$/"],
      matchStrings: [
        "chart:\\s*(?<chartPath>[\\w./-]+)\\s*\\n[^\\S\\n]*version:\\s*(?<currentValue>[^\\s\"']+)",
      ],
      depNameTemplate: "{{{chartPath}}}",
      datasourceTemplate: "helm",
      packageNameTemplate: "{{{chartPath}}}",
    },
    // Flux OCI repository refs
    {
      customType: "regex",
      description: ["Flux OCI repository refs."],
      managerFilePatterns: [
        "/(^|/)cluster/flux/meta/repositories/oci/.+\\.ya?ml$/",
      ],
      matchStrings: [
        'url:\\s*oci://(?<depNamePath>[^\\s]+)[^\\S\\n]*\\n(?:[\\s\\S]*?)?ref:\\s*\\n[^\\S\\n]*tag:\\s*"?(?<currentValue>[^"\\s]+)"?',
      ],
      depNameTemplate: "{{{depNamePath}}}",
      datasourceTemplate: "docker",
      packageNameTemplate: "{{{depNamePath}}}",
    },
    // OCI artifact references in cluster manifests
    {
      customType: "regex",
      description: ["OCI artifact references in cluster manifests."],
      managerFilePatterns: ["/(^|/)cluster/.+\\.ya?ml$/"],
      matchStrings: [
        'artifact:\\s*"?oci://(?<depNamePath>[^:"\\s]+)(?::|@)(?<currentValue>[^"\\s]+)"?',
      ],
      depNameTemplate: "{{{depNamePath}}}",
      packageNameTemplate: "{{{depNamePath}}}",
      datasourceTemplate: "docker",
    },
    // Container images in Taskfiles and cluster manifests
    {
      customType: "regex",
      description: [
        "Container images in Taskfiles, scripts, and cluster manifests.",
      ],
      managerFilePatterns: [
        "/(^|/)\\.taskfiles/.+\\.(ya?ml|tmpl\\.ya?ml)$/",
        "/(^|/)\\.taskfiles/.+/scripts/.+\\.(sh|bash)$/",
        "/(^|/)cluster/.+\\.ya?ml$/",
      ],
      matchStrings: [
        "image:\\s*(?<depName>[^:\\s]+):(?<currentValue>[^\\s\"']+)",
        "(?<depName>(?:ghcr|docker\\.io|quay\\.io|registry\\.k8s\\.io)[^:\\s]+):(?<currentValue>[^\\s\"']+)",
      ],
      depNameTemplate: "{{{depName}}}",
      packageNameTemplate: "{{{depName}}}",
      datasourceTemplate: "docker",
    },
  ],
}
```

#### package-rules.json5

```json5
{
  $schema: "https://docs.renovatebot.com/renovate-schema.json",
  packageRules: [
    // ============ Docker/OCI ============
    {
      matchDatasources: ["docker", "oci"],
      enabled: true,
      commitMessageTopic: "container image {{depName}}",
      commitMessageExtra: "to {{#if isSingleVersion}}v{{{newVersion}}}{{else}}{{{newValue}}}{{/if}}",
      pinDigests: false,
    },
    {
      matchDatasources: ["docker", "oci"],
      matchUpdateTypes: ["major"],
      labels: ["renovate/image", "dep/major"],
    },
    {
      matchDatasources: ["docker", "oci"],
      matchUpdateTypes: ["minor"],
      labels: ["renovate/image", "dep/minor"],
    },
    {
      matchDatasources: ["docker", "oci"],
      matchUpdateTypes: ["patch"],
      labels: ["renovate/image", "dep/patch"],
    },

    // ============ Helm ============
    {
      matchDatasources: ["helm"],
      separateMinorPatch: true,
      ignoreDeprecated: true,
    },
    {
      matchDatasources: ["helm"],
      matchUpdateTypes: ["major"],
      labels: ["renovate/helm", "dep/major"],
    },
    {
      matchDatasources: ["helm"],
      matchUpdateTypes: ["minor"],
      labels: ["renovate/helm", "dep/minor"],
    },
    {
      matchDatasources: ["helm"],
      matchUpdateTypes: ["patch"],
      labels: ["renovate/helm", "dep/patch"],
    },

    // ============ Managers ============
    {
      matchManagers: ["github-actions"],
      labels: ["renovate/github-actions"],
      minimumReleaseAge: "2 days",
    },
    {
      matchManagers: ["terraform"],
      labels: ["renovate/terraform"],
      separateMinorPatch: true,
    },
    {
      matchManagers: ["devcontainer"],
      labels: ["renovate/devcontainer"],
    },
    {
      matchManagers: ["npm"],
      labels: ["renovate/npm"],
    },
    {
      matchManagers: ["pip_requirements"],
      labels: ["renovate/python"],
    },
    {
      matchManagers: ["pre-commit"],
      labels: ["renovate/pre-commit"],
    },
    {
      matchManagers: ["flux"],
      labels: ["renovate/flux"],
    },
    {
      matchManagers: ["kubernetes"],
      labels: ["renovate/kubernetes"],
    },
    {
      matchManagers: ["helm-values"],
      labels: ["renovate/helm-values"],
    },

    // ============ Custom regex by path ============
    {
      matchManagers: ["custom.regex"],
      labels: ["renovate/script"],
    },
    {
      matchManagers: ["custom.regex"],
      matchFileNames: ["**/flavor.yaml"],
      labels: ["renovate/megalinter-flavor"],
    },
    {
      matchManagers: ["custom.regex"],
      matchFileNames: ["**/metadata.yaml"],
      labels: ["renovate/upstream"],
    },
    {
      matchManagers: ["custom.regex"],
      matchFileNames: [".taskfiles/**"],
      labels: ["renovate/taskfile"],
      pinDigests: false,
    },
    {
      matchManagers: ["custom.regex"],
      matchFileNames: ["talos/**"],
      labels: ["renovate/talos"],
      minimumReleaseAge: "3 days",
    },
  ],
}
```

#### groups.json5

```json5
{
  $schema: "https://docs.renovatebot.com/renovate-schema.json",
  packageRules: [
    {
      description: "Rook-Ceph operator, cluster chart, and Ceph container image",
      groupName: "Rook Ceph",
      matchPackageNames: [
        "ghcr.io/rook/rook-ceph",
        "ghcr.io/rook/rook-ceph-cluster",
        "quay.io/ceph/ceph",
      ],
      matchDatasources: ["docker", "helm", "oci"],
      group: { commitMessageTopic: "{{{groupName}}} group" },
      separateMinorPatch: true,
    },
    {
      description: "Traefik chart and CRD",
      groupName: "Traefik",
      matchPackageNames: ["traefik", "traefik-crd-source"],
      matchDatasources: ["helm", "regex", "github-tags"],
      group: { commitMessageTopic: "{{{groupName}}} group" },
      separateMinorPatch: true,
    },
    {
      description: "Cilium CNI",
      groupName: "Cilium",
      matchPackageNames: [
        "quay.io/cilium/cilium",
        "quay.io/cilium/operator-generic",
        "cilium",
      ],
      matchDatasources: ["helm", "docker"],
      separateMinorPatch: true,
      minimumReleaseAge: "2 days",
    },
    {
      description: "Victoria Metrics components",
      groupName: "Victoria Metrics",
      matchPackageNames: [
        "victoria-metrics",
        "victoriametrics",
        "ghcr.io/victoriametrics/helm-charts",
      ],
      matchDatasources: ["helm", "docker", "oci"],
      group: { commitMessageTopic: "{{{groupName}}} group" },
      separateMinorPatch: true,
    },
    {
      description: "External Secrets Operator",
      groupName: "External Secrets",
      matchPackageNames: ["external-secrets"],
      matchDatasources: ["helm"],
      group: { commitMessageTopic: "{{{groupName}}} group" },
      separateMinorPatch: true,
      minimumReleaseAge: "7 days",
    },
    {
      description: "CloudNativePG components",
      groupName: "CloudNativePG",
      matchPackageNames: ["cloudnative-pg", "cnpg"],
      matchDatasources: ["helm", "docker"],
      group: { commitMessageTopic: "{{{groupName}}} group" },
      separateMinorPatch: true,
    },
    {
      description: "Flux components",
      groupName: "Flux",
      matchPackageNames: ["fluxcd/*", "ghcr.io/fluxcd/*"],
      matchDatasources: ["docker", "helm", "github-releases"],
      group: { commitMessageTopic: "{{{groupName}}} group" },
      separateMinorPatch: true,
      minimumReleaseAge: "7 days",
    },
    {
      description: "Authentik stack",
      groupName: "Authentik",
      matchPackageNames: ["goauthentik/*", "ghcr.io/goauthentik/*"],
      matchDatasources: ["docker", "helm"],
      group: { commitMessageTopic: "{{{groupName}}} group" },
      separateMinorPatch: true,
    },
    {
      description: "Cert-Manager components",
      groupName: "Cert-Manager",
      matchPackageNames: ["cert-manager", "jetstack/cert-manager"],
      matchDatasources: ["helm", "docker"],
      group: { commitMessageTopic: "{{{groupName}}} group" },
      separateMinorPatch: true,
      minimumReleaseAge: "7 days",
    },
    {
      description: "External-DNS components",
      groupName: "External-DNS",
      matchPackageNames: ["external-dns", "kubernetes-sigs/external-dns"],
      matchDatasources: ["helm", "docker"],
      group: { commitMessageTopic: "{{{groupName}}} group" },
      separateMinorPatch: true,
    },
    {
      description: "Snapshot Controller components",
      groupName: "Snapshot Controller",
      matchPackageNames: [
        "snapshot-controller",
        "kubernetes-csi/external-snapshotter",
      ],
      matchDatasources: ["helm", "docker"],
      group: { commitMessageTopic: "{{{groupName}}} group" },
      separateMinorPatch: true,
    },
    {
      description: "CI/CD Actions",
      groupName: "CI/CD Actions",
      matchManagers: ["github-actions"],
      matchPackageNames: ["actions/*", "docker/*"],
      group: { commitMessageTopic: "{{{groupName}}} group" },
    },
    {
      description: "BJW-S App Template",
      groupName: "App Template",
      matchPackageNames: ["ghcr.io/bjw-s-labs/helm/app-template"],
      matchDatasources: ["helm"],
      group: { commitMessageTopic: "{{{groupName}}} group" },
    },
    {
      description: "Kubernetes and Talos",
      groupName: "Kubernetes/Talos",
      matchPackageNames: ["kubernetes", "siderolabs/talos"],
      matchDatasources: ["docker", "github-releases", "custom.regex"],
      group: { commitMessageTopic: "{{{groupName}}} group" },
    },
  ],
}
```

#### automerge.json5

```json5
{
  $schema: "https://docs.renovatebot.com/renovate-schema.json",
  // Top-level automerge settings
  automerge: true,
  automergeType: "pr",
  automergeStrategy: "squash",
  platformAutomerge: true,

  packageRules: [
    // ============ Default automerge by update type ============
    {
      description: "Automerge patch, digest, and pin updates",
      matchUpdateTypes: ["patch", "digest", "pin"],
      automerge: true,
    },
    {
      description: "Don't automerge minor updates (override per-repo if desired)",
      matchUpdateTypes: ["minor"],
      automerge: false,
    },
    {
      description: "Don't automerge major updates",
      matchUpdateTypes: ["major"],
      automerge: false,
    },

    // ============ Manager-specific automerge ============
    {
      description: "Automerge GitHub Actions minor updates",
      matchManagers: ["github-actions"],
      matchUpdateTypes: ["minor"],
      automerge: true,
    },
    {
      description: "Automerge pre-commit minor updates",
      matchManagers: ["pre-commit"],
      matchUpdateTypes: ["minor"],
      automerge: true,
    },
    {
      description: "Automerge Terraform provider minor updates",
      matchManagers: ["terraform"],
      matchDatasources: ["terraform-provider"],
      matchUpdateTypes: ["minor"],
      automerge: true,
    },

    // ============ Package-specific overrides ============
    {
      description: "Disable automerge for rook-ceph (critical storage component)",
      matchPackagePatterns: ["^(ghcr\\.io/)?rook(/|-)ceph"],
      automerge: false,
    },
  ],
}
```

#### custom-datasources.json5

```json5
{
  $schema: "https://docs.renovatebot.com/renovate-schema.json",
  customDatasources: {
    "artifacthub-headlamp": {
      defaultRegistryUrlTemplate: "https://artifacthub.io/api/v1/packages/headlamp/{{packageName}}",
      format: "json",
      transformTemplates: [
        '{ "releases": [$map(available_versions, function($v) { { "version": $v.version } })] }',
      ],
    },
  },
}
```

#### disabled.json5

```json5
{
  $schema: "https://docs.renovatebot.com/renovate-schema.json",
  packageRules: [
    {
      description: "Disable kubernetes-api datasource (noisy, not useful)",
      matchManagers: ["kubernetes"],
      matchDatasources: ["kubernetes-api"],
      enabled: false,
    },
  ],
}
```

### xfg Config Changes

Update `src/config.yaml` files section:

```yaml
files:
  # ... existing files ...

  # Renovate - remove createOnly to always sync
  .github/renovate.json5:
    content: "@templates/.github/renovate.json5"
  .github/renovate/base.json5:
    content: "@templates/.github/renovate/base.json5"
  .github/renovate/managers.json5:
    content: "@templates/.github/renovate/managers.json5"
  .github/renovate/custom-managers/annotated.json5:
    content: "@templates/.github/renovate/custom-managers/annotated.json5"
  .github/renovate/custom-managers/infrastructure.json5:
    content: "@templates/.github/renovate/custom-managers/infrastructure.json5"
  .github/renovate/package-rules.json5:
    content: "@templates/.github/renovate/package-rules.json5"
  .github/renovate/groups.json5:
    content: "@templates/.github/renovate/groups.json5"
  .github/renovate/automerge.json5:
    content: "@templates/.github/renovate/automerge.json5"
  .github/renovate/custom-datasources.json5:
    content: "@templates/.github/renovate/custom-datasources.json5"
  .github/renovate/disabled.json5:
    content: "@templates/.github/renovate/disabled.json5"
```

### Per-Repo Overrides

Example for spruyt-labs `ignorePaths`:

```yaml
repos:
  - git: https://github.com/anthony-spruyt/spruyt-labs.git
    files:
      .github/renovate/base.json5:
        content:
          ignorePaths: ["talos/helmfile"]
```

Example to enable minor automerge for a repo:

```yaml
repos:
  - git: https://github.com/anthony-spruyt/some-repo.git
    files:
      .github/renovate/automerge.json5:
        content:
          packageRules:
            $arrayMerge: append
            - matchUpdateTypes: ["minor"]
              automerge: true
```

## Key Decisions

1. **Modular structure** - Split by concern (base, managers, rules, etc.) for maintainability
2. **Generic file patterns** - Use broad patterns (all YAML, all shell) and let annotations filter
3. **Patches automerge by default** - Conservative approach, minors require review unless overridden
4. **`separatePatchReleases` enabled** - Separate PRs for patches vs minors for finer control
5. **Infrastructure patterns included** - K8s/Flux/Helm patterns present but only match repos with those paths

## Implementation Steps

1. Create template files in `src/templates/.github/renovate/`
2. Update `src/config.yaml` to add new file entries and remove `createOnly` from renovate.json5
3. Add per-repo overrides as needed (e.g., spruyt-labs ignorePaths)
4. Run xfg to sync to all repos
5. Verify Renovate dashboard in each repo shows correct config
