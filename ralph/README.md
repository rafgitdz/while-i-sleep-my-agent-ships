# ralph/: the overnight loop

Copy this folder to `scripts/ralph/` in the product repository.

```text
tasks/                       written by the `prd` skill: the specs, in Markdown
├── prd-<feature>.md             one per feature
└── codebase-patterns.md         patterns accumulated over the runs

scripts/ralph/               everything the loop needs
├── ralph.sh                     the loop
├── CLAUDE.md                    the prompt sent to `claude --print` on each iteration
├── prd.json                     written by the `ralph` skill: THE source of truth
├── progress.txt                 the memory, read first by the next iteration
└── archive/YYYY-MM-DD-<feature>/  prd.json + progress.txt of each finished run
```

**The loop never reads `tasks/`.** `ralph.sh` only knows its own folder: the
`ralph` skill is the only bridge between the spec and the loop.

## Run

```bash
# Once: the two skills, from the upstream marketplace
/plugin marketplace add snarktank/ralph
/plugin install ralph-skills@ralph-marketplace

# 1. The spec, in Markdown           -> tasks/prd-<feature>.md
/ralph-skills:prd <feature description>

# 2. Its conversion                  -> scripts/ralph/prd.json
/ralph-skills:ralph tasks/prd-<feature>.md

# 3. Check, then start the loop
./scripts/ralph/ralph.sh --dry-run
./scripts/ralph/ralph.sh 20
```

| Option | Effect |
|---|---|
| `--system-prompt-file FILE` | Appends `FILE` to the system prompt of every iteration (a style or a skill you want applied without fail) |
| `--dry-run` | Prints the command; touches no file, calls no model |
| `<number>` | Maximum iterations, 10 by default |

## Archiving

`ralph.sh` archives **when the run exits**, not when it starts. At exit,
`prd.json` and `progress.txt` both belong to the run that just ended, and the
folder name comes from the `branchName` of that same `prd.json`.

Upstream archives at startup. But the `ralph` skill writes the next feature's
`prd.json` before the loop starts, overwriting the previous one: the loop then
files the NEXT PRD under the PREVIOUS feature's name, and the whole history
shifts by one. The defect is known upstream
([#99](https://github.com/snarktank/ralph/issues/99),
[#125](https://github.com/snarktank/ralph/issues/125)).

Commit `scripts/ralph/`, archive included: a run history that lives on one
machine is not a history. The loop commits `prd.json` and `progress.txt` at
every validated story, so git can always show a PRD as a run left it:

```bash
git log -- scripts/ralph/prd.json
git show <sha>:scripts/ralph/prd.json
```

## Safety

`claude --dangerously-skip-permissions` lets the agent run any command without
asking. Run the loop in a container or a VM that holds **no production
credential**: the agent works on a branch, CI gates the merge, and production
stays behind a manual delivery.
