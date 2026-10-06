---
name: herdr-floor-manager
description: "Coordinate supervised implementation-review loops in Herdr: current Codex manages a watched Codex implementer and a read-only Claude running the full Paladin panel. Every participating LLM must load precise-technical-communication 2.0.0-eval1 before work. Not for ordinary single-agent work."
---

# Herdr Floor Manager

Coordinate one writer and one independent reviewer while the current Codex owns scope, decisions, and the final handoff.

Use the deterministic watchdog for liveness. Do not delegate supervision to another LLM agent.

## Mandatory Communication Policy

`precise-technical-communication` version `2.0.0-eval1` is a hard dependency for the coordinator and every LLM that participates in this workflow. This includes the Codex implementer, Claude reviewer, every nested delegate, and every Paladin panel voice. The deterministic watchdog is not an LLM and is excluded.

1. Before task work, each LLM must read the complete installed `SKILL.md`, verify that `metadata.version` is exactly `2.0.0-eval1`, and complete the PTC Bootstrap in [references/role-prompts.md](references/role-prompts.md).
2. A missing file, unreadable file, version mismatch, or inability to pass the requirement to a nested agent is a blocking condition. Do not substitute another version or continue with an unenforced reminder.
3. The requirement persists for every turn. Include the continuation clause in every work, review, and fix prompt. Re-run the bootstrap after a worker restart, replacement, context reset, or session recreation.
4. A worker may create or invoke another LLM only when it can inject the same bootstrap and verify the child's exact ready marker before the child starts. Paladin voices count as child agents. If the Paladin harness cannot propagate and verify the policy for every default voice, do not launch the panel.
5. Apply the skill's meaning, evidence, uncertainty, terminology, modality-selection, and agent-status rules to all work. For creative writing, verbatim quotations, or code-only output, keep the semantic and evidence safeguards without imposing technical-prose style, as the skill itself requires.

Higher-priority instructions still control. This policy does not expand task scope, permissions, or authorization.

## Preconditions

1. Require `HERDR_ENV=1` and `HERDR_PANE_ID`. Run `herdr pane current --current` and require its `agent` field to be `codex`. Otherwise stop: this workflow requires the current Codex pane to remain coordinator.
2. Resolve and verify the PTC installation paths before controlling panes. Prefer `$HOME/.agents/skills/precise-technical-communication/SKILL.md` for Codex; otherwise use `${CODEX_HOME:-$HOME/.codex}/skills/precise-technical-communication/SKILL.md`. Use `$HOME/.claude/skills/precise-technical-communication/SKILL.md` for Claude. Require the exact version above at every selected path. The current coordinator must load its selected file now.
3. Read the current Herdr CLI before controlling panes:

   ```bash
   herdr agent
   herdr pane
   ```

   Confirm `python3` is also available for the bundled watchdog.

4. Confirm `codex`, `claude`, and every voice in Paladin's default roster are available (currently Claude, Codex, and Muse), and that Paladin exposes `/paladin:review-code`. Confirm the reviewer can propagate the PTC Bootstrap to every default voice and verify their ready markers. If any required voice, Paladin, or propagation mechanism is unavailable, stop. Do not substitute an ordinary or degraded review.
5. Consult the current `codex-first` skill from the sibling agent-scripts skill or its installed copy only for launch arguments. Translate its launch recipe to interactive Codex arguments: retain the current execution-policy, model, reasoning, and service-tier settings, but omit noninteractive-only tokens such as `exec`, `resume`, `-C`, `-o`, and stdin `-`. In this explicitly requested Herdr crew workflow, `codex-first`'s direct self-delegation hard gate does not apply; this skill owns the specialized crew launch. If the recipe is unavailable or cannot be translated, stop instead of launching a differently configured implementer.
6. Inspect the current pane, layout, agents, repository instructions, and working-tree state. Record the pre-task baseline and preserve unrelated changes and existing panes. If unrelated changes overlap the task's review scope, require a task-owned isolated checkout/worktree or an owner decision before implementation.
7. Establish the task, scope, acceptance criteria, task-specific review target, and relevant deterministic checks. Ask only when a missing choice would materially change the implementation.

Before launching workers, read [references/role-prompts.md](references/role-prompts.md).

## Ownership

- **Coordinator (current Codex):** owns scope, instructions, evidence, finding triage, stopping decisions, and the user-facing result. It does not compete with the implementer by editing the same files.
- **Implementer (new Codex):** is the only source-code writer. It inspects, edits, and runs relevant checks. It never pushes, submits, lands, or publishes unless the user separately authorizes that action.
- **Reviewer (new Claude):** stays read-only and invokes the default full `/paladin:review-code` workflow. It never fixes findings or modifies repository sources.
- **Watchdog (bundled script):** observes one worker's Herdr status and terminal revision. It never edits, prompts, retries, or decides that work succeeded.

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

5. Before sending any role work, send each new or reused LLM worker the filled PTC Bootstrap through the turn protocol. Require `PTC_READY:<turn-token>` from the worker. A worker with `PTC_BLOCKED:<turn-token>` or no valid ready marker cannot receive task, review, fix, or Paladin prompts.

## Implementation And Review Loop

### Turn Protocol

Apply this turn protocol every time the coordinator sends a filled prompt template that carries `<turn-token>`: the PTC Bootstrap, Implementer Contract, Reviewer Verdict Request, and Fix Request.

1. Require the worker to be `idle` or `done`, record its current Herdr `revision` as `N`, set one absolute turn deadline, and generate a fresh unique token that has not appeared in any earlier prompt.
2. Replace `<turn-token>` with the fresh token. Require `herdr agent prompt --wait` to observe `working`; `blocked` is an immediate stop.
3. After `prompt --wait` observes `working`, take a subsequent `agent get` snapshot and require its revision `M` to be greater than `N`; `M` does not need to be captured while the worker is still `working`. If the snapshot is `blocked`, stop. If it is `working`, `idle`, or `done`, supervise the turn with the watchdog; an `idle` or `done` snapshot lets the watchdog return immediately before marker validation:

   ```bash
   herdr agent get <worker-name> # require idle/done; record revision N
   herdr agent prompt <worker-name> '<filled template with fresh turn token>' --wait --until working --until blocked --timeout 30000 # require working
   herdr agent get <worker-name> # record revision M; retry this read within the deadline until M > N
   scripts/watch-agent.sh --after-revision N --start-revision M --stall-seconds <redraw-cap-seconds> --timeout-seconds <whole-seconds-remaining-before-deadline> <worker-name>
   ```

   Do not run the watchdog if the prompt command fails, stalls, returns `blocked`, or does not observe `working`. The prompt response can observe `working` before its terminal revision advances, so `M > N` is mandatory even when the next snapshot is already `idle` or `done`. Run the watchdog as one blocking command so it returns as soon as the worker becomes ready, unhealthy, stops redrawing, or reaches the task cap. The task cap is mandatory and is the real liveness bound because spinner redraws can advance Herdr's revision without useful progress.

4. A zero exit means only that Herdr reported `idle` or `done` at or after the verified start revision. Read the response and accept only an exact standalone marker made from the required prefix, one colon, and this turn's token: `PTC_READY` for the PTC Bootstrap, `IMPLEMENTATION_COMPLETE` for the Implementer Contract or Fix Request, and `REVIEW_COMPLETE` for the Reviewer Verdict Request. Strip leading whitespace and one TUI bullet, but allow nothing after the token. Treat `PTC_BLOCKED` or `IMPLEMENTATION_BLOCKED`, one colon, and this turn's token as a blocked stop requiring an owner decision. Never accept a marker containing an earlier token. The prompt describes how to construct the line but never contains the complete marker verbatim.

Exit 2 means the agent vanished or entered blocked, persistently unknown, or unexpected state; exit 3 means the TUI stopped redrawing; exit 4 means this watchdog invocation exhausted the remaining task cap; exit 5 means bounded Herdr or Python polling failed. Exit 64 means the coordinator supplied invalid watchdog arguments; it never authorizes a new deadline. Rerunning the watchdog is safe because it only observes, but it does not reset the turn deadline. Recompute and pass only the whole seconds remaining before the original deadline. If no whole second remains, do not invoke the watchdog and treat the turn as exit 4. Each `herdr agent get` poll timeout is at most the configured value, defaults to ten seconds, and is clamped to the remaining turn time. The task cap cannot interrupt unrelated shell or Herdr commands outside the watchdog.

Never ask the watchdog to resend a prompt. Retry only when Herdr refused before sending anything, or when `agent read` proves the prompt appears in neither the transcript nor input box and the worker is `idle` or `done`. A timeout, transport error, lack of edits, or stalled response does not prove nondelivery. In every uncertain case, stop for an owner decision rather than risking duplicate work.

### Workflow

1. Bootstrap the implementer and reviewer through the turn protocol. Record their resolved PTC paths, exact version, ready tokens, and any nested-agent propagation evidence. Do not continue until both are ready.
2. Send the implementer the filled Implementer Contract through the turn protocol.
3. Confirm the implementer reports the changed files, checks run, results, and remaining uncertainty. Inspect the working-tree diff and relevant source yourself without editing it.
4. Compare the result with the recorded baseline and build an explicit task-file coverage list, classifying modified, deleted, renamed, and untracked files. Require a diff-bearing Paladin target for the tracked delta; path-only review cannot prove deletions or rename preimages. Confirm an immutable diff version or commit contains the exact implementation bytes before using it. For remaining untracked task files, use the repository-native noncommitting add only in a task-owned isolated checkout, or supplement every review cycle with exact-file targets. Never alter a user-managed index merely to satisfy review. Run deterministic checks before model review; if checks fail, return the evidence to the implementer first.
5. Give the reviewer the exact Paladin launch from the reference only after the reviewer confirms that every panel voice will receive and acknowledge the PTC Bootstrap. This bare slash-command turn carries no turn token. Its completion evidence is a finalized Paladin report path with no outstanding Paladin roles; reserve `REVIEW_COMPLETE` token validation for the later Reviewer Verdict Request. Record the pre-prompt revision and run the same `N`/`working`/`M` start gate and watchdog after confirmed delivery. If Claude returns to `idle` while Paladin still has background roles, record the watchdog's ready revision as `R` and inspect those roles. Immediately before re-arming, run `herdr agent get <review-name>`. If the revision advanced beyond `R` and the reviewer is already `idle` or `done`, read its new output for a finalized Paladin report path and inspect role state again; update `R` and repeat the pre-wait check if background roles remain. If the reviewer is `working`, use the new revision as the next start revision and run the watchdog without waiting. Arm the wait only while the reviewer remains ready at revision `R` and background roles remain:

   ```bash
   herdr agent wait <review-name> --until working --until blocked --timeout <remaining-milliseconds>
   ```

   Herdr 0.9.3 does not expose a revision-aware wait, so the pre-wait snapshot closes the observable lost-wakeup window. If the wait times out, re-read status, output, and role state before treating it as watchdog exit 4; accept a finalized report path only when no Paladin roles remain, or continue from an observed transition instead of discarding completion evidence. After `working`, take a fresh `agent get` snapshot for start revision `M`, then rerun the watchdog against the existing run with only the seconds left before the same original deadline. The wait timeout uses milliseconds, while the watchdog timeout uses seconds. Never launch a duplicate review. Default review means the complete registered Paladin pass-by-voice matrix:
   - never pass `--fast`;
   - never pass `--no-claude`, `--no-codex`, or `--no-muse`;
   - never use `--symphony`, `--security`, `--all`, or another mode unless the user explicitly requests it.
6. After Paladin completes, send the Reviewer Verdict Request through the turn protocol. Read enough reviewer output to capture every actionable finding and the report artifact paths.
   Treat any excluded, unavailable, failed, or degraded default voice as an incomplete panel. Never report `CLEAR` or "full panel" until every required voice completed without that limitation.
7. Triage findings against the task and source. Send accepted findings verbatim with the Fix Request template through the turn protocol. If an uncertain finding requires another Reviewer Verdict Request, send it through the turn protocol with a fresh token. Do not let either worker silently broaden scope.
8. After fixes and checks, recompute the complete coverage plan before rerunning full Paladin. The diff-bearing target must contain the fixed bytes, and every remaining untracked file must receive the same exact-file supplemental review again. A pinned diff version or `--hash` target is immutable and cannot validate later local fixes. Stop when the verdict is clear or after two fix-review cycles. At the cap, report remaining findings to the user instead of continuing indefinitely.

## Coordination Rules

- One writer at a time. The reviewer and coordinator remain read-only while implementation is active.
- Treat `idle` and `done` as ready, `working` as in progress, and `blocked` or `unknown` as requiring inspection and possibly user input.
- Preserve exact file, line, command, test, and report references. Do not paraphrase a finding into a stronger claim.
- Record which Paladin target covered each task file. Do not report a full-panel clear verdict while any changed or new file is outside the reviewed snapshot.
- Never infer success from an agent message alone. Verify source state and deterministic checks.
- Reject task or review output from an LLM whose current session lacks a verified PTC Bootstrap. A prose claim that the skill was used is not a substitute for the exact ready marker and recorded path/version.
- Every worker prompt must carry the PTC continuation clause. Every nested LLM prompt must carry the full bootstrap. If a worker cannot enforce either rule, treat it as blocked.
- Do not merge, push, submit a diff, resolve comments, or publish from this skill unless the user explicitly requested that external action.
- Do not close the worker panes automatically. Leave them available for inspection and report their names in the handoff.

## Closeout

Report:

- implementer and reviewer names;
- files and behavior changed;
- deterministic checks and results;
- Paladin mode, final verdict, and report paths;
- accepted, fixed, rejected, and unresolved findings;
- coordinator, worker, nested-agent, and Paladin PTC paths, versions, and bootstrap status;
- working-tree and submission state;
- the precise next action, if any.
