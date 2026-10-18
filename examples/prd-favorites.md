# PRD: Favorite listings

> Example written for this repository, modeled on the PRDs that drove real
> overnight runs. Generated with the `prd` skill, then converted to
> [`prd.json`](./prd.json) with the `ralph` skill.

## Introduction

Signed-in users want to set a listing aside and find it later. Add a heart
button on every listing card and a "My favorites" page in the account area.
A favorite keeps a snapshot of the listing's display fields, so it stays
readable after the listing expires or is deleted.

## Goals

- Save or remove a favorite in one click from any listing card.
- List favorites, newest first, paginated.
- Keep a favorite readable when its listing is gone, clearly marked as such.

## User stories

### US-001: API contract for favorites
**Description:** As a developer, I change the OpenAPI contract first (the project is contract-first) to expose the favorites endpoints.

**Acceptance criteria:**
- [ ] `openapi/favorite-api.yaml` declares `POST /api/favorites`, `DELETE /api/favorites/{listingId}`, `GET /api/favorites` (paginated) and `GET /api/favorites/ids`
- [ ] `POST` answers 201, 401, 404, 409 (already a favorite), 422
- [ ] `/api/favorites/ids` is declared before `/api/favorites/{listingId}`
- [ ] The build generates the `FavoriteApi` interface; generated code is never edited
- [ ] Build passes

### US-002: Favorite model, snapshot and repository
**Description:** As a developer, I store a favorite with a snapshot of the listing's display fields.

**Acceptance criteria:**
- [ ] `Favorite` holds `userId`, `listingId`, `createdAt` and an embedded `ListingSnapshot`
- [ ] Uniqueness of (`userId`, `listingId`) is checked in the service, not only by an index
- [ ] Repository tests pass

### US-003: Create and delete a favorite
**Description:** As a signed-in user, I add or remove a favorite.

**Acceptance criteria:**
- [ ] Adding an existing favorite returns 409 with an RFC 7807 problem body
- [ ] Adding a favorite on an unknown listing returns 404
- [ ] Deleting is idempotent from the user's point of view
- [ ] Unit tests cover the three cases; all tests pass

### US-004: List favorites with fallback on the snapshot
**Description:** As a signed-in user, I see my favorites, even those whose listing is gone.

**Acceptance criteria:**
- [ ] Each item exposes `sourceAvailable` and `expired`
- [ ] When the listing still exists, the snapshot is refreshed on read
- [ ] When it does not, the snapshot is returned, read-only
- [ ] All tests pass

### US-005: Heart button on listing cards
**Description:** As a signed-in user, I toggle a favorite from a listing card.

**Acceptance criteria:**
- [ ] The button is hidden for anonymous visitors
- [ ] Clicking it does not follow the card link (`stopPropagation` + `preventDefault`)
- [ ] The state comes from a single call to `/api/favorites/ids`
- [ ] Component tests pass; verify in the browser

### US-006: "My favorites" page
**Description:** As a signed-in user, I browse my favorites in my account area.

**Acceptance criteria:**
- [ ] Paginated list, newest first
- [ ] "Expired" and "No longer available" badges; no contact button on those items
- [ ] Empty state with a link back to the listings
- [ ] Component tests pass; verify in the browser

## Non-goals

- Notifications on a favorite, folders or tags, sharing, public counters.
- Anonymous favorites stored in the browser.

## Technical considerations

- Contract-first: the YAML changes before any Java code.
- One story per iteration: each story leaves the build green and is committed alone.
