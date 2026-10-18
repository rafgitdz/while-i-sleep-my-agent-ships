# <Product name>

<!-- Template of the root CLAUDE.md of the product repository. The overnight
     loop reads it on every iteration: keep it short, factual and current. -->

## Business context

<!-- Three to five lines: what the product does, for whom, and the domain
     vocabulary the agent must use (one line per term). -->

## Architecture

| | Backend | Frontend |
|---|---|---|
| **Folder** | `api/` | `ui/` |
| **Stack** | <language, framework, build tool> | <framework, language> |
| **Tests** | `<exact command>` | `<exact command>` |
| **E2E** | - | `<exact command>` |

## Continuous integration and delivery

- **Nothing ships automatically.** A green push on `main` builds, tests and
  publishes an image tagged `sha-xxxxxxx`, then stops.
- Production is a deliberate act: *Actions* > *Deliver to production* > the tag.
- Delivery keeps its safety net: health probes, and automatic rollback to the
  previous tag if they fail.
- Images are built by CI, never on the server: what ships is exactly what was tested.

## Workflow

- **After every code change**: commit, without waiting to be asked.
- **Tests**: always run them after a change. If any test fails, including a
  pre-existing one, fix it before committing.
- **Contract-first**: change the OpenAPI file, build, then write code. Never
  edit generated sources.
- **Documentation**: for every feature or fix, update `CHANGELOG.md`, and the
  README or deployment guide when the change affects them.
