<div align="center">

# While I sleep, my agent ships

**The harness behind an AI agent that delivers features overnight, on a real product in production.**<br>
A spec it can follow, a loop that never runs out of context, and a delivery pipeline it cannot bypass.

[![CI](https://github.com/rafgitdz/while-i-sleep-my-agent-ships/actions/workflows/ci.yml/badge.svg)](https://github.com/rafgitdz/while-i-sleep-my-agent-ships/actions/workflows/ci.yml)
![Claude Code](https://img.shields.io/badge/Claude%20Code-headless-d97757)
![loop](https://img.shields.io/badge/loop-Ralph-yellow)
![license](https://img.shields.io/badge/license-MIT-green)

[The problem](#the-problem) · [How it works](#how-it-works) · [Results](#results) · [Lessons learned](#lessons-learned) · [Use it](#use-it) · [Watch the talk](#the-talk) · [Book this talk](#book-this-talk)

</div>

---

## The problem

After months of "vibe coding", we were still babysitting the agent. Long
sessions saturate the context window, and the agent drifts: it forgets the
conventions, repeats a mistake it fixed an hour ago, or declares victory on a
red build.

The question behind this repository: **can an agent ship on its own, at night,
on a real product with real users, without anyone watching it?**

## How it works

```text
 DAY (human, minutes)          NIGHT (agent, hours)                  MORNING (human)
 ────────────────────          ────────────────────                  ───────────────
 /ralph-skills:prd             ralph.sh, one fresh Claude Code       review the branch
   → tasks/prd-x.md            instance per iteration:               open the PR
 /ralph-skills:ralph             1. read prd.json + progress.txt     CI: build, tests,
   → scripts/ralph/prd.json      2. pick the top story, passes:false     immutable image
                                 3. implement it, run the checks     "Deliver to production"
                                 4. commit, set passes: true             with the tag
                                 5. append learnings to progress.txt health probes,
                               until every story passes                auto rollback
```

Three ideas carry the whole thing:

1. **Memory lives on disk, not in the model.** Each iteration starts a fresh
   instance with an empty context. What it needs to know is in three places: a
   structured PRD (`prd.json`), a progress log whose first section is a list of
   codebase patterns (`progress.txt`), and the committed code.
2. **One story per iteration, each one verifiable.** Acceptance criteria are
   concrete ("POST answers 409 when already a favorite", "build passes"). The
   first story of a backend feature is always the OpenAPI contract: the
   generated interfaces make the next stories checkable by the compiler.
3. **Nothing ships automatically.** The agent works on a branch. CI publishes an
   immutable image and stops. Production is a button a human presses, protected
   by health probes and an automatic rollback.

### Context economy

The context fills from both ends, so each end gets a gate:

- **What goes in**: [rtk](https://github.com/rtk-ai/rtk), a CLI proxy that
  condenses command output before the model reads it. Measured on my own
  commands: 28.9 % of terminal noise removed.
- **What comes out**: [caveman](https://github.com/JuliusBrussee/caveman)
  compresses the agent's prose and leaves code, commands and errors intact,
  injected with `--system-prompt-file`.

## Results

Measured on [AmanaRoo](https://amanaroo.com), a Spring Boot and Angular
community platform in production with real users, and shown live at Volcamp
2026 ([replay](https://youtu.be/K69kq1dcePc)):

- **80+ backlog features shipped over the first five weeks**, with **at most
  two hours a day** of human involvement.

What the run archives show, from March to October 2026:

| | |
|---|---|
| Overnight runs archived | 13 |
| User stories validated by the loop (`passes: true`) | 98 |
| Runs whose final state was lost (before `prd.json` was tracked in git) | 3 |

The talk also covers the numbers that do not go my way. Some of them are in
the [lessons learned](#lessons-learned) below.

## Lessons learned

Each one cost at least one night.

| What happened | What changed |
|---|---|
| The agent binary was missing from `PATH`. The loop swallows per-iteration errors on purpose, so all iterations ran empty | `ralph.sh` fails fast when the binary is missing |
| "Use the X skill" in the prompt never invoked the skill: 156 messages, 0 Skill tool calls. The model obeys the text, not the rules file | `--system-prompt-file` appends the file to the system prompt, identically on every iteration |
| Runs were archived under the wrong feature name: the next PRD overwrote the previous one before the loop started (upstream [#99](https://github.com/snarktank/ralph/issues/99), [#125](https://github.com/snarktank/ralph/issues/125)) | Archive on exit, when PRD and progress belong to the same run |
| In a multi-repository workspace, the agent committed at the root and its work was not in the sub-repository: two iterations lost | One line in the Codebase Patterns of `progress.txt`, which every following iteration reads first |
| Three runs lost their final state: `prd.json` was not tracked in git yet | All of `scripts/ralph/` is committed, archive included |
| An agent running with `--dangerously-skip-permissions` can run any command | The loop runs in an isolated environment with no production credential; production sits behind a manual, probed delivery |

Read [`examples/progress.txt`](./examples/progress.txt) to see what the
Codebase Patterns section looks like after a few iterations.

## Use it

```text
ralph/                 the loop: ralph.sh + the prompt sent on each iteration
examples/              a PRD, its prd.json and a progress log, in English
delivery/workflows/    CI that publishes an immutable image, manual delivery with probes and rollback
templates/CLAUDE.md    the root CLAUDE.md of the product repository
```

1. Copy `ralph/` to `scripts/ralph/` in your product repository, and
   `templates/CLAUDE.md` to its root. Fill in the stack and the test commands.
2. Install the two skills: `/plugin marketplace add snarktank/ralph`, then
   `/plugin install ralph-skills@ralph-marketplace`.
3. Write the PRD (`/ralph-skills:prd`), convert it (`/ralph-skills:ralph`),
   check with `./scripts/ralph/ralph.sh --dry-run`, then start the loop.
4. Copy `delivery/workflows/` to `.github/workflows/`, set the repository
   variables and secrets listed at the top of `deliver-reusable.yml`, and protect
   the `production` environment.

Details in [`ralph/README.md`](./ralph/README.md).

## Credits

The loop is [Ralph](https://github.com/snarktank/ralph) by snarktank (MIT),
itself built on Geoffrey Huntley's
[Ralph pattern](https://ghuntley.com/ralph/). Changes made here are
listed at the top of [`ralph/ralph.sh`](./ralph/ralph.sh).

## The talk

| Year | Event | Title | Language | Replay |
|---|---|---|---|---|
| 2026 | Volcamp | While I Sleep, My Agent Ships: 80+ Features in 5 Weeks | FR | [YouTube](https://youtu.be/K69kq1dcePc) |
| 2026 | WAX Conference | While I Sleep, My Agent Ships | FR | |

## Book this talk

Available as a keynote, a 2-hour meetup or a podcast, in French or English.
With a live demo in production: the agent implements and validates a feature in
front of the audience, on the real site.

**[Request a quote](https://tally.so/r/Y5LRev)** · [LinkedIn](https://www.linkedin.com/in/rafik-ferroukh) · [YouTube](https://www.youtube.com/@TheUnBullshIT)

## License

[MIT](./LICENSE)
