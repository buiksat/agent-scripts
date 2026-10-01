# Role Prompts

Read this reference when creating or reusing a floor-manager crew. Replace angle-bracket placeholders with task evidence. Do not send literal placeholders.

## Implementer Contract

```text
You are the sole implementation owner for this task.

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

Send the chosen slash command exactly as a reviewer prompt. Do not add `--fast`, any `--no-<voice>` flag, or a different mode unless the user explicitly requested it.

## Reviewer Verdict Request

After the Paladin run settles, send:

```text
Using only the completed Paladin report and verified source, return:
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
