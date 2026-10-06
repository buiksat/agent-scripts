# Role Prompts

Read this reference when creating or reusing a floor-manager crew. Replace angle-bracket placeholders with task evidence. Do not send literal placeholders.

## PTC Bootstrap

Send this to every LLM worker before any other work prompt. Fill `<agent-kind>` and `<ptc-path>` from the verified preconditions. Send the same requirement to every nested LLM, including every Paladin voice.

```text
You are an <agent-kind> participating in a Herdr floor-manager workflow.

Before any task work, read the complete skill file at:
<ptc-path>

Verify that its YAML metadata version is exactly `2.0.0-eval1`. Use that precise-technical-communication skill for every remaining turn in this session. Apply its semantic-preservation, evidence, uncertainty, terminology, modality-selection, verification, and agent-status rules to all applicable work. For creative writing, verbatim quotations, or code-only output, retain its semantic and evidence safeguards without imposing technical-prose style.

If you create or invoke any LLM child, delegate, reviewer, or panel voice, give it this same bootstrap with the correct installed path and require its exact ready marker before it starts. Paladin voices count as children. If you cannot propagate and verify this requirement, do not delegate or launch the panel.

Do not treat this policy as authorization to broaden scope or perform external actions.

Report the resolved path and observed version. Then end with a standalone line made from `PTC_READY`, a colon, and the turn token `<turn-token>`. If the file is missing, unreadable, has another version, or cannot be propagated to a required child, report the exact problem and end with `PTC_BLOCKED`, a colon, and the same token.
```

## PTC Continuation Clause

Include this paragraph in every Implementer Contract, Reviewer Verdict Request, and Fix Request:

```text
Continue applying the loaded precise-technical-communication skill version `2.0.0-eval1`. Preserve its evidence and agent-status distinctions in this response. Do not delegate to an LLM that has not completed the same bootstrap in its current session.
```

## Implementer Contract

```text
You are the sole implementation owner for this task.

Continue applying the loaded precise-technical-communication skill version `2.0.0-eval1`. Preserve its evidence and agent-status distinctions in this response. Do not delegate to an LLM that has not completed the same bootstrap in its current session.

Goal:
<goal>

Scope and acceptance criteria:
<scope-and-criteria>

Repository instructions and constraints:
<instructions-and-constraints>

Known evidence and relevant paths:
<evidence-and-paths>

Required checks:
<checks>

Inspect the relevant source before editing. Preserve unrelated work. Implement the smallest coherent fix or feature, add focused tests when appropriate, and run the required checks. Do not push, submit, land, publish, or edit outside the stated scope.

When finished, report:
1. root cause or implementation approach;
2. files changed and why;
3. checks run with exact results;
4. remaining risks or uncertainties;
5. current working-tree state.

End the report with a standalone line made from `IMPLEMENTATION_COMPLETE`, then a colon, then the turn token `<turn-token>`. If you cannot finish, use `IMPLEMENTATION_BLOCKED`, a colon, and the same token as a standalone line, then state the exact blocker before that line.
```

## Full Paladin Launch

Choose a diff-bearing primary target that contains the exact implementation:

- uncommitted implementation in a clean or task-isolated checkout: `/paladin:review-code`
- Phabricator diff only when the exact reviewed version already contains the implementation: `/paladin:review-code D<number>:<version>`
- local Git commit only when that exact commit contains the complete implementation: `/paladin:review-code --hash=<commit> [<repository-path>]`

If unrelated changes overlap the task scope, create a task-owned isolated checkout/worktree with the repository-native workflow before implementation. If safe isolation is unavailable, stop and ask the owner; do not use a noisy whole-working-copy review as proof.

Before launching review:

1. Verify the primary target's actual patch contains every tracked modification, deletion, rename, and rename preimage from the task. A file or directory target is not a substitute for this diff-bearing review.
2. For an immutable diff version or commit, verify its revision and file contents match the completed implementation. If later local edits exist, use the working-copy target instead.
3. Newly created files that remain untracked are absent from the working-copy diff. In an isolated task checkout, add them through the repository-native noncommitting workflow, or run `/paladin:review-code <exact-file-path>` separately for every remaining untracked task file.
4. Record every primary and supplemental target-to-file mapping in the final handoff.
5. Confirm that every Paladin voice will receive the PTC Bootstrap and that the reviewer can verify each exact `PTC_READY` marker. If the harness cannot provide that evidence, do not launch Paladin and report `PTC_BLOCKED` through the turn protocol.

Send the chosen slash command exactly as a reviewer prompt. Do not add `--fast`, any `--no-<voice>` flag, or a different mode unless the user explicitly requested it.

## Reviewer Verdict Request

After the Paladin run settles, send:

```text
Using only the completed Paladin report and verified source, return:
Continue applying the loaded precise-technical-communication skill version `2.0.0-eval1`. Preserve its evidence and agent-status distinctions in this response. Do not delegate to an LLM that has not completed the same bootstrap in its current session.
- VERDICT: CLEAR or CHANGES_REQUIRED
- every actionable finding with severity, file:line, failure mode, and required invariant
- findings rejected or downgraded by verification
- deterministic proof checked and remaining gaps
- every report limitation, including excluded, unavailable, failed, or degraded voices
- exact report and report-details paths

Stay read-only. Do not modify source files, run fixes, or broaden the review scope.
If any default Paladin voice is excluded, unavailable, failed, or degraded, set VERDICT to CHANGES_REQUIRED and state that the full panel did not complete.
End with a standalone line made from `REVIEW_COMPLETE`, then a colon, then the turn token `<turn-token>`.
```

## Fix Request

```text
Address only the accepted review findings below. Preserve unrelated changes and existing behavior outside scope.

Continue applying the loaded precise-technical-communication skill version `2.0.0-eval1`. Preserve its evidence and agent-status distinctions in this response. Do not delegate to an LLM that has not completed the same bootstrap in its current session.

<verbatim-accepted-findings>

For each finding, verify the failure mode, implement the ownership-correct fix, add or update focused tests when appropriate, and rerun the required checks. Do not push, submit, land, or publish.

Report each finding as fixed, rejected with evidence, or unresolved, followed by exact check results and working-tree state.
End with a standalone line made from `IMPLEMENTATION_COMPLETE`, then a colon, then the turn token `<turn-token>`. If you cannot finish, use `IMPLEMENTATION_BLOCKED`, a colon, and the same token as a standalone line, then state the exact blocker before that line.
```

## Final Review

After fixes, recompute the full coverage plan:

- use a diff-bearing working-copy target when fixes are still local;
- use a new Phabricator version only after it has been created with separate user authorization and verified to contain the fixed bytes;
- use a new commit hash only after that commit exists and contains the complete fixed implementation;
- repeat exact-file supplemental reviews for every task file that remains untracked.

Never rerun an immutable old diff version or commit hash and claim it validates later fixes. Run the full Paladin command against every updated primary and supplemental target and request the same bounded verdict. Do not weaken the roster or switch to fast mode for the final pass.

Before every rerun, reconfirm the reviewer session's PTC bootstrap and require the reviewer to reconfirm propagation and ready markers for every new Paladin voice.
