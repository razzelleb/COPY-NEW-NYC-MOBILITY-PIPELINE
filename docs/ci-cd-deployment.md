# NYC Mobility CI/CD Deployment

## Overview

The NYC Mobility project uses **GitHub Actions** and **Databricks Asset Bundles** to automate code validation and deployment.

The CI/CD process connects GitHub and Databricks so that changes can be tested before they are deployed.

The overall flow is:

```text
Code Change
    ↓
Pull Request
    ↓
GitHub Actions
    ↓
Validation
    ↓
Merge
    ↓
Deploy to Databricks
    ↓
Databricks Job
    ↓
NYC Mobility Pipeline
```
---

## Repository Structure

The CI/CD setup depends on the following project structure:

```text
.
├── .github/
│   └── workflows/
│       └── ci-cd.yml
│
├── src/
│   └── sql/
│       ├── 00_setup/
│       ├── 01_bronze_ingest/
│       ├── 02_silver_clean/
│       ├── 03_gold_model/
│       └── 05_analytics/
│
├── tests/
│
├── resources/
│   └── nyc_mobility_job.yml
│
├── databricks.yml
└── docs/
```

The main CI/CD configuration files are:

* [`/.github/workflows/ci-cd.yml`](../.github/workflows/ci-cd.yml) — GitHub Actions workflow.
* [`/databricks.yml`](../databricks.yml) — Databricks Asset Bundle configuration.
* [`/resources/nyc_mobility_job.yml`](../resources/nyc_mobility_job.yml) — Databricks Job and task configuration.

---

# 1. CI/CD Workflow

## Pull Request Validation

When a Pull Request is opened against `main` or `develop`, GitHub Actions runs the validation process.

The purpose is to identify problems before changes are merged.

The validation includes:

* Checking out the repository.
* Setting up Python.
* Installing test dependencies.
* Checking for whitespace errors.
* Running `pytest`.

A Pull Request **does not deploy the Databricks Job**.

The workflow is configured in:

[`/.github/workflows/ci-cd.yml`](../.github/workflows/ci-cd.yml)

### Validation Flow

```text
Pull Request
     ↓
GitHub Actions
     ↓
Install dependencies
     ↓
Repository checks
     ↓
Pytest
     ↓
PASS → Ready to merge
FAIL → Fix changes
```

---

# 2. Deployment

After changes are merged, deployment is determined by the target branch:

```text
develop → DEV
main    → PROD
```

The deployment process first runs the validation job.

Only after validation succeeds does the corresponding deployment job run.

```text
Push / Merge
      ↓
Validation
      ↓
   PASS?
   /   \
 NO     YES
 ↓       ↓
Stop   Deploy
         ↓
     Databricks
```

The branch-to-environment behavior is defined in:

[`/.github/workflows/ci-cd.yml`](../.github/workflows/ci-cd.yml)

---

# 3. GitHub Actions Configuration

The GitHub Actions workflow controls when validation and deployment occur.

The workflow should contain:

* Trigger configuration.
* Validation job.
* Development deployment job.
* Production deployment job.
* Databricks authentication configuration.
* Databricks CLI installation.
* Bundle validation.
* Bundle deployment.

The complete workflow should be maintained in:

[`/.github/workflows/ci-cd.yml`](../.github/workflows/ci-cd.yml)

### Important Configuration

A data engineer reproducing this project should check the following before using the workflow:

| Configuration             | Purpose                              |
| ------------------------- | ------------------------------------ |
| `main` branch             | Production deployment                |
| `develop` branch          | Development deployment               |
| `DATABRICKS_HOST`         | Databricks workspace URL             |
| `DATABRICKS_TOKEN`        | Authentication for deployment        |
| GitHub `dev` environment  | Development deployment configuration |
| GitHub `prod` environment | Production deployment configuration  |

The Databricks credentials should be stored as **GitHub Secrets**, rather than being written directly into the workflow.

---

# 4. Databricks Asset Bundle

The Databricks Asset Bundle provides the deployment structure for the project.

The configuration is maintained in:

[`/databricks.yml`](../databricks.yml)

The bundle should define:

* The bundle name.
* Resource files to include.
* Development target.
* Production target.
* Workspace configuration where required.

The project uses two targets:

```text
DEV
 │
 └── develop

PROD
 │
 └── main
```

### Replication Requirement

A new data engineer should review the `workspace` configuration in `databricks.yml` before deployment.

The workspace path should point to a location that the deploying user or service principal can access.

Do not copy another engineer's personal workspace path unless that path is intentionally being used by the new environment.

---

# 5. Databricks Authentication

GitHub Actions needs permission to communicate with the Databricks workspace.

For this project, authentication is provided through:

```text
DATABRICKS_HOST
DATABRICKS_TOKEN
```

These values are configured as GitHub Secrets and are passed to the deployment jobs through environment variables.

A replicated setup therefore requires:

1. Access to the target Databricks workspace.
2. A valid authentication method.
3. The Databricks workspace host.
4. A credential with sufficient permissions.
5. The corresponding values configured in GitHub Secrets.

The actual credentials should **never be committed to the repository**.

---

# 6. Databricks Job

The Databricks Job represents the executable NYC Mobility pipeline.

The Job configuration is maintained in:

[`/resources/nyc_mobility_job.yml`](../resources/nyc_mobility_job.yml)

The pipeline follows the project's Medallion architecture:

```text
Setup
  ↓
Bronze Ingestion
  ↓
Silver Cleaning
  ↓
Gold Modeling
  ↓
Analytics
```

Each task points to a corresponding SQL or Python file under `src/`.

---

# 7. SQL Warehouse Configuration

SQL tasks in the Databricks Job require a SQL Warehouse.

The warehouse configuration is referenced by the SQL tasks in:

[`/resources/nyc_mobility_job.yml`](../resources/nyc_mobility_job.yml)

When replicating the project, the data engineer should:

1. Create or identify an appropriate SQL Warehouse.
2. Confirm that it is available in the target Databricks workspace.
3. Confirm that the deploying identity can use the warehouse.
4. Update the warehouse identifier in the Job configuration.

The warehouse identifier should not be assumed to be the same across different Databricks workspaces.

---

# 8. Retry and Failure Notifications

The pipeline uses retries for tasks where temporary failures are more likely, particularly:

* External data downloads.
* Bronze ingestion.

The purpose of retries is to allow the pipeline to recover from temporary failures without immediately stopping the entire workflow.

The general behavior is:

```text
Task starts
    ↓
Temporary failure
    ↓
Retry
    ↓
Success → Continue
    │
    └── Failure
          ↓
      Retry again
          ↓
      Final failure
          ↓
   Failure notification
```

Failure notifications are configured in the Databricks Job so that designated recipients can be notified when the pipeline ultimately fails.

The retry and notification configuration is maintained in:

[`/resources/nyc_mobility_job.yml`](../resources/nyc_mobility_job.yml)

### Replication Requirement

When reproducing the project, replace the notification recipients with the appropriate team or project email addresses.

Do not copy project-specific email addresses without confirming that they are still valid.

---

# 9. Environments

The project separates development and production using Git branches and Databricks Bundle targets.

```text
GitHub
  │
  ├── develop → DEV
  │
  └── main    → PROD
```

The purpose of this separation is to allow changes to be tested in development before being deployed to production.

A replicated project should ensure that:

* The `develop` branch exists if development deployment is required.
* The `main` branch is used for production.
* The `dev` Databricks target is configured.
* The `prod` Databricks target is configured.
* GitHub environments and secrets are configured appropriately.

---

# 10.  Verification

After configuring the project, deployment should be verified in both GitHub and Databricks.

### GitHub Actions

Confirm that:

```text
Validation
   ↓
PASS
   ↓
Deployment
   ↓
PASS
```

The workflow should show successful execution of the appropriate deployment job.

# 11. Deployment Flow

The complete CI/CD process is:

```text
                    GitHub
                       │
                 Pull Request
                       │
                       ▼
              ┌─────────────────┐
              │ GitHub Actions  │
              │                 │
              │ Validation      │
              │ Pytest          │
              └────────┬────────┘
                       │
                  Merge Changes
                       │
              ┌────────┴────────┐
              │                 │
          develop              main
              │                 │
              ▼                 ▼
             DEV               PROD
              │                 │
              └────────┬────────┘
                       ▼
             Databricks Bundle
                       │
                       ▼
              Databricks Job
                       │
                       ▼
             NYC Mobility Pipeline
```

---
# Summary

The NYC Mobility CI/CD setup provides a repeatable process for moving project changes from GitHub into Databricks.

The responsibilities are separated between the tools:

```text
GitHub
  → Source control

GitHub Actions
  → Validation and deployment automation

Pytest
  → Repository testing

Databricks CLI
  → Communication with Databricks

Asset Bundle
  → Databricks deployment configuration

Databricks Job
  → NYC Mobility pipeline execution
```

