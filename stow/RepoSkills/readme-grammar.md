# README Grammar

RepoSkills does not ship a README template. It ships this grammar, and generates a repo-specific
`.ai/skills/readme-template.md` from it during Phase 2. Read `## Project System` and `## Unit List`
from `state.md` before generating.

## Adopt and align

Where the target repo already has a README convention, adopt it. The section names and section set
in this file are the fallback for a repo with no existing convention, never a standard to impose on
one that does: a generated template that disagrees with a checker the repo already runs creates two
competing conventions, and every README that satisfies one fails the other.

**Detect an existing convention in this order.** The first source found is authoritative; later
ones only fill what it leaves unstated.

1. **CI enforcement.** Search the repo's CI scripts and workflows for a README structure check
   (grep the CI directory for `readme`). What such a checker enforces, the section names, order,
   skeleton membership and any exact required text it tests, is the convention's definition, adopted
   verbatim: it is what merges are gated on.
2. **A README template document**, commonly `docs/readme-template.md` or similar. Adopt its
   skeletons, its section names and its conditional-section list.
3. **A conventions document** that names README sections.
4. **The de facto pattern.** Where none of the above exists but most existing unit READMEs share a
   section set, induce that set and confirm it through the induction loop below before adopting it.

**When the repo's names and this file's names disagree, the repo's names win.** Map by role, never
by string: the repo's post-Overview operational-links section fills the Monitoring slot whatever it
is called, its configuration-pointer section fills the Environment Variables slot, and so on.
Record the mapping in the generated template, so a drafting agent never reintroduces the fallback
names.

**A recurring section this grammar does not name is adopted, not dropped.** A section name that
recurs across the repo's conformant READMEs in the conditional slot is a repo-convention
conditional section: add it to the generated template's conditional list with a one-line contents
note induced from how the repo uses it, and confirm the note through the induction loop.

**When the sources disagree with each other**, a template internally inconsistent, or out of step
with the checker or with the READMEs: whatever CI enforces wins, because it is what merges are
gated on. Where no check settles the conflict, follow the majority of existing conformant READMEs,
record the inconsistency in the run report, and put the question to a human through the induction
loop's venue. Never silently pick a side, and never emit a template the repo's own checker would
fail.

How far a run may restructure an existing README to align it with the adopted convention (the
bounded write territory) is settled in spec section 3.2, marker-based on `provenance=generated`
rather than positional, and is implemented in 2a-ii. This is not an open question; this file governs
only what the generated template says.

## Two skeletons, chosen by deployability

A unit is deployable when the repo's `deployability-predicate` says it ships. Otherwise nothing runs
and the sections about running and watching it do not apply. The names below are the fallback set,
following the reference implementation's converged names, and are used verbatim only where Adopt and
align found no existing convention.

| Section | Full (deployable) | Slim | Contains |
|---|---|---|---|
| Title | yes | yes | The unit's canonical name as the project system reports it |
| Conventions info-box | yes | yes | A link to `conventions.md` and the override rule |
| Overview | yes | yes | One or two sentences on what the unit does and why |
| Monitoring | yes | no | Only where a link pattern was confirmed. Unfillable rows stay `_not yet linked_` |
| Running and testing locally | yes | no | The quick loop, plus only what is specific to this unit |
| Agent Notes | yes | yes | Gotchas and what the code cannot tell you. **Always last** |

**Conditional sections**, either skeleton, after Running and testing locally and before Agent Notes,
only where the substrate exists: `Endpoints` (an API surface), `Environment Variables` (a pointer to
the declaring file, never values), `Runbook` (operational failure modes with known responses), one
or more unit-specific topics named for what they are, and any recurring repo-convention section
Adopt and align found. A unit may legitimately carry several: a monitoring service can have both a
dashboards section and an alert-rules section.

Section order is fixed. A slim README on a small library is the correct output, not a failure.

## What to include

A README carries what the code cannot: the why, the gotchas, the cross-unit consequences. Include a
unit-specific fact only if it survives both questions:

1. Could an agent get this right in about **10 seconds** from this unit's own code and config?
   If no, keep it.
2. If yes, does it also carry a why, a gotcha, a cross-unit consequence, or quick-start orientation?
   If no, cut it.

Cut anything both trivially greppable and none of those: a source directory tree, the DI framework
name, an endpoint list mirroring the controllers.

**Version numbers are the classic cut.** Manifests and lockfiles are the source of truth. Name a
version only where the unit deliberately pins something different, and say what it differs from.

**Link, never list.** Environment variables, configuration values, credentials, profile and role
names: point at the declaring file, or name the variable. Never reproduce the value. A value copied
into a README is wrong for every reader but its author, and is a second source of truth by
definition. If the declaring file is itself wrong, fix that file rather than documenting the
discrepancy.

**Every section is a positive contract, never a prohibition list.** State what the section contains,
in order. The `Environment Variables` slot reads "pointer to the declaring file", so there is no
table to negotiate away. This is deliberate: agents under a competing incentive negotiate with
prohibitions, and prohibition-form guidance measurably backfires on wrong-output-shape failures.

**Agent Notes bullets cite their sources.** A bullet asserting a repo fact ends with the path or
paths it derives from, so the next agent can verify the claim before acting on it and a drift check
can test whether it still holds. A bullet that cannot name its source is a guess, and guesses do
not belong in Agent Notes.

## Pattern induction with human confirmation

For any field whose shape is repo-specific (observability links, dashboard URLs, the deployability
predicate, the test command shape):

1. **Discover.** Find N real examples of the artifact in the repo.
2. **Induce.** Derive a pattern with the variable parts identified.
3. **Confirm.** Present the examples and the derived pattern to the human: "here are three log links
   I found and the pattern I derived; does this generalise?"
4. **Record.** The confirmed pattern goes into `.ai/skills/conventions.md`, in the repo. Never into
   `state.md`: that lives on one machine, so anyone else cloning the repo would get placeholders or
   a repeated interview.
5. **Apply.** Per-unit values are computed from the confirmed pattern.

**An unconfirmed pattern produces a placeholder, never a guess.** `_not yet linked_` is a
first-class output: an empty row flags the document as incomplete, while a dropped row hides the gap
and a guessed one is worse than both.

Once confirmed, a field that was non-deterministic becomes deterministic. Fields that resist
induction because they genuinely vary per unit must be resolved and verified per unit or omitted.
Never pattern-filled.

**Venue.** The Phase 1 interview when it runs, and the Phase 9 checkpoint otherwise, since Phase 1
is skipped when `domain-context.md` is fresh. Unconfirmed patterns block the Phase 9 skip. When no
human answers, the headless case, placeholders stand and the report carries the list forward: a
blocked skip must never become a hung pipeline.

## Token budget

The agent-facing sections of a README carry a ceiling of roughly 1.5k tokens, matching what module
skills carried. The human-authored Overview is excluded from the count, since it is not RepoSkills'
to trim. Overflow goes to a task skill rather than splitting the README, because a unit has exactly
one README.

**Enforcement is generation-time only.** An existing README over budget is flagged in the report,
never truncated. The ceiling binds what RepoSkills writes; it does not license editing down what a
human wrote.

## Generating the repo-specific template

Run Adopt and align first. Then write `.ai/skills/readme-template.md` containing: both skeletons as
fenced markdown blocks with this repo's real commands and the adopted section names substituted in,
the name mapping wherever the repo's names differ from this file's fallbacks, the include test
verbatim, the Agent Notes citation rule, the conditional section list filtered to those this repo
has substrate for plus the recurring sections Adopt and align found, and an authoring-rules banner
the drafting agent honours and then deletes.

Head the two skeleton blocks **`Full skeleton (deployable)`** and **`Slim skeleton
(non-deployable)`**, those exact headings, so a drafting agent reading the generated template can
tell the two blocks apart without guessing.

Do **not** include `Contracts owned`, `Deviations` or `Lifecycle status`. Those three are absent
from the reference implementation and land in a later stage with their own baseline test. Shipping
them now would flag every pre-existing README in the target repo as incomplete. None of these three
names may appear anywhere in the generated template, including in the authoring-rules banner: naming
them there to warn the drafting agent still ships the words the omission was meant to avoid.
