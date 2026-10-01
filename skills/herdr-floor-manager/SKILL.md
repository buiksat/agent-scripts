---
name: herdr-floor-manager
description: "Coordinate explicit implementation-review loops in Herdr: current Codex supervises, one Codex writes, and one read-only Claude runs the full Paladin panel. Not for ordinary single-agent work."
---

# Herdr Floor Manager

Coordinate one writer and one independent reviewer while the current Codex owns scope, decisions, and the final handoff.

## Preconditions

1. Require `HERDR_ENV=1` and `HERDR_PANE_ID`. Run `herdr pane current --current` and require its `agent` field to be `codex`. Otherwise stop: this workflow requires the current Codex pane to remain coordinator.
2. Read the current Herdr CLI before controlling panes:

   ```bash
   herdr agent
   herdr pane
   ```

3. Confirm `codex`, `claude`, and every voice in Paladin's default roster are available (currently Claude, Codex, and Muse), and that Paladin exposes `/paladin:review-code`. If any required voice or Paladin is unavailable, stop. Do not substitute an ordinary or degraded review.
4. Read the current `codex-first` launch recipe from the sibling agent-scripts skill or its installed copy. Translate it to interactive Codex arguments: retain the current execution-policy, model, reasoning, and service-tier settings, but omit noninteractive-only tokens such as `exec`, `resume`, `-C`, `-o`, and stdin `-`. If the recipe is unavailable or cannot be translated, stop instead of launching a differently configured implementer.
5. Inspect the current pane, layout, agents, repository instructions, and working-tree state. Record the pre-task baseline and preserve unrelated changes and existing panes. If unrelated changes overlap the task's review scope, require a task-owned isolated checkout/worktree or an owner decision before implementation.
6. Establish the task, scope, acceptance criteria, task-specific review target, and relevant deterministic checks. Ask only when a missing choice would materially change the implementation.

Before launching workers, read [references/role-prompts.md](references/role-prompts.md).

## Ownership

- **Coordinator (current Codex):** owns scope, instructions, evidence, finding triage, stopping decisions, and the user-facing result. It does not compete with the implementer by editing the same files.
- **Implementer (new Codex):** is the only source-code writer. It inspects, edits, and runs relevant checks. It never pushes, submits, lands, or publishes unless the user separately authorizes that action.
- **Reviewer (new Claude):** stays read-only and invokes the default full `/paladin:review-code` workflow. It never fixes findings or modifies repository sources.

Do not add more workers merely for speed. Expand the crew only when the user asks or the task has clearly independent write scopes.

## Create Or Reuse The Crew

Use names derived from the task, limited to `[a-z][a-z0-9_-]{0,31}`. Prefer `<slug>_impl` and `<slug>_review`; append a digit on collision.

1. Run `herdr agent list`. A new work order always gets a fresh implementer and reviewer. Reuse a worker only when this coordinator created it earlier in the same task invocation, such as a fix-review cycle; record its existing name and pane, never run `agent start` for it again, and never take over an unrelated or prior-task agent.
2. Create panes only for missing roles. Pin every topology operation to the caller: discover with `herdr pane current --current`, retain `$HERDR_PANE_ID` as the coordinator pane, and use explicit parsed pane IDs. When both roles are missing, split the coordinator right for the implementer and split that still-empty new pane down for the reviewer before starting either agent. When one role is reused, split an appropriate explicit shell pane for only the missing role; never split an occupied worker pane merely to satisfy the default shape. Keep the crew in the current workspace, use `--no-focus`, and never rely on UI focus. Set both new panes' `--cwd` to the verified task root; when isolation is required, that root is the task-owned isolated checkout, never the caller's dirty checkout. Reused same-task workers must already use that root.
3. If that layout would create unusably small panes, choose a bounded alternative in the same workspace. Do not close or move panes you did not create.
4. Start only newly created workers with Herdr; prompt reused workers in place:

   ```bash
   herdr agent start <impl-name> --kind codex --pane <impl-pane> --timeout 300000 -- <interactive-codex-first-worker-arguments>
   herdr agent start <review-name> --kind claude --pane <review-pane> --timeout 300000
   ```

If startup returns blocked or times out, inspect the agent before retrying. Never bypass an approval or repeat a prompt whose delivery is uncertain.

## Implementation And Review Loop

1. Send the implementer the filled implementation contract from the reference. Use `herdr agent prompt ... --wait` and a task-appropriate timeout. On timeout, inspect state and output before deciding whether to continue.
2. Confirm the implementer reports the changed files, checks run, results, and remaining uncertainty. Inspect the working-tree diff and relevant source yourself without editing it.
3. Compare the result with the recorded baseline and build an explicit task-file coverage list, classifying modified, deleted, renamed, and untracked files. Require a diff-bearing Paladin target for the tracked delta; path-only review cannot prove deletions or rename preimages. Confirm an immutable diff version or commit contains the exact implementation bytes before using it. For remaining untracked task files, use the repository-native noncommitting add only in a task-owned isolated checkout, or supplement every review cycle with exact-file targets. Never alter a user-managed index merely to satisfy review. Run deterministic checks before model review; if checks fail, return the evidence to the implementer first.
4. Give the reviewer the exact Paladin launch from the reference. Default review means the complete registered Paladin pass-by-voice matrix:
   - never pass `--fast`;
   - never pass `--no-claude`, `--no-codex`, or `--no-muse`;
   - never use `--symphony`, `--security`, `--all`, or another mode unless the user explicitly requests it.
5. After Paladin completes, ask the reviewer for the bounded verdict format from the reference. Read enough reviewer output to capture every actionable finding and the report artifact paths.
   Treat any excluded, unavailable, failed, or degraded default voice as an incomplete panel. Never report `CLEAR` or "full panel" until every required voice completed without that limitation.
6. Triage findings against the task and source. Send accepted findings verbatim to the implementer; ask the reviewer to clarify uncertain findings. Do not let either worker silently broaden scope.
7. After fixes and checks, recompute the complete coverage plan before rerunning full Paladin. The diff-bearing target must contain the fixed bytes, and every remaining untracked file must receive the same exact-file supplemental review again. A pinned diff version or `--hash` target is immutable and cannot validate later local fixes. Stop when the verdict is clear or after two fix-review cycles. At the cap, report remaining findings to the user instead of continuing indefinitely.

## Coordination Rules

- One writer at a time. The reviewer and coordinator remain read-only while implementation is active.
- Treat `idle` and `done` as ready, `working` as in progress, and `blocked` as requiring inspection and possibly user input.
- Preserve exact file, line, command, test, and report references. Do not paraphrase a finding into a stronger claim.
- Record which Paladin target covered each task file. Do not report a full-panel clear verdict while any changed or new file is outside the reviewed snapshot.
- Never infer success from an agent message alone. Verify source state and deterministic checks.
- Do not merge, push, submit a diff, resolve comments, or publish from this skill unless the user explicitly requested that external action.
- Do not close the worker panes automatically. Leave them available for inspection and report their names in the handoff.

## Closeout

Report:

- implementer and reviewer names;
- files and behavior changed;
- deterministic checks and results;
- Paladin mode, final verdict, and report paths;
- accepted, fixed, rejected, and unresolved findings;
- working-tree and submission state;
- the precise next action, if any.
