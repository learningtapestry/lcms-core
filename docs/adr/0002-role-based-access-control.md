# ADR-0002: Role-Based Access Control for Sensitive Operations

|                   |                                                                                              |
|-------------------|----------------------------------------------------------------------------------------------|
| **Status**        | Draft                                                                                        |
| **Date**          | 2026-06-09                                                                                   |
| **Supersedes**    | —                                                                                            |
| **Superseded by** | —                                                                                            |
| **Related**       | [ADR-0001](./0001-pluggable-output-renderers.md)                                             |

---

## 1. Context

LCMS Core currently has a binary authentication model:

- **Anonymous** — public document/material viewing.
- **Authenticated** — anyone signed in via Devise (`authenticate_user!`).
- **Admin** — controllers under `Admin::` namespace use `authenticate_admin!`.

There is no per-resource ownership check, no team/organization scoping, and no
fine-grained capability model. Several operations that *should* be restricted
to the resource owner (or an admin) are currently reachable by any authenticated
user who can guess or enumerate the resource identifier (IDOR).

This ADR is a placeholder to track the operations that need role-based or
ownership-based access control before a proper RBAC layer is introduced.

## 2. Decision

To be defined. Candidate approaches:

- **Pundit** policies per resource class (`DocumentPolicy`, `JobResultPolicy`).
- **CanCanCan** ability rules centralized in `Ability`.
- Hand-rolled `before_action` ownership checks (short-term mitigation).

The chosen approach will:

1. Introduce a `Role` (or capability) model attached to `User`.
2. Replace blanket `authenticate_user!` with policy checks where applicable.
3. Provide an audit trail of which controllers/actions were migrated.

## 3. Inventory of Operations Requiring RBAC

The list below tracks endpoints and operations that today rely on
`authenticate_user!` alone but expose resource-scoped data and should be
re-evaluated under the future RBAC model.

### 3.1 Job-status polling

| Operation                                | Controller / Action                                      | Risk                                                                                                  |
|------------------------------------------|----------------------------------------------------------|-------------------------------------------------------------------------------------------------------|
| Read async job status and S3 result URL  | `Api::DocumentJobsController#status`                     | IDOR — any authenticated user can poll any `job_id` (UUIDv4) and read another user's PDF link.        |

**Refactor candidate.** `Api::DocumentJobsController` currently inherits from
`ApplicationController` and exposes `/api/document_jobs/:job_id/status` to any
signed-in session. There is no link between `job_id` and the user who enqueued
the job. Once RBAC lands, this controller should either:

- Inherit from `Admin::AdminController` (if status polling is admin-only), **or**
- Persist `user_id` on `JobResult` (and/or check via the wrapped `Document`/
  `Material` ownership) and authorize via policy.

A short-term mitigation is documented in ADR-0001's related PR (#69) and
should be revisited as part of this RBAC effort.

### 3.2 Document and material reads

*To be inventoried.* Public `DocumentsController` and `MaterialsController`
actions need to be classified into:

- Truly public (no auth) — current behavior is correct.
- Authenticated but currently leaking cross-user data — needs scoping.

### 3.3 Admin actions

*To be inventoried.* Today the `Admin::` namespace gates everything behind
`authenticate_admin!`. With RBAC we may split:

- Super-admin (settings, user management).
- Content editor (documents, materials, standards).
- Read-only auditor (reports, dashboards).

## 4. Consequences

- Until RBAC ships, new endpoints exposing per-resource data must add
  ownership checks inline and reference this ADR.
- This document is the canonical place to add new entries to the inventory.
  When a feature PR introduces a new sensitive endpoint, append a row to the
  appropriate section in §3.

## 5. Open Questions

- Library choice (Pundit vs. CanCanCan vs. hand-rolled).
- Multi-tenancy story — does each `User` belong to an `Organization`?
- Migration path for existing data — backfilling `user_id` on legacy records.