# The Gateworlds Constitution

**Status: draft.** Adopted 2026-09-20 by the founding maintainer, who at the time of writing
is the only person it binds. It takes effect now and is amendable from now
(§5).

---

## 0. What this document can and cannot do today

There is one maintainer. Most of what a constitution usually does — distribute authority,
resolve disputes, bind a majority — needs more than one person, and saying otherwise would
be theatre.

So this document does two things that work with one person:

1. **It constrains the maintainer**, including in ways they cannot undo (§3.3). A rule that
   only binds other people is not a constitution.
2. **It writes down the procedure before it is needed**, because after it is needed there
   is nobody with the standing to write it.

Clauses that require more than one person are marked **[dormant]**. They are not
aspirational language; they are rules waiting for the condition that activates them.

## 1. Scope

This document governs the project: its code, its protocol, its worlds, its documents and
its decisions. It does not govern anyone's own copy — see §6.

Where this document and another disagree, this one wins, except that it cannot override a
licence already granted (§3.3).

## 2. Principles, and the mechanism for each

A principle with no mechanism is a preference. Each of these names the thing that actually
enforces it.

### 2.1 Open creation

Anyone may propose ideas, worlds, code and changes to the rules, without permission and
without signing anything.

**Mechanism:** [`CONTRIBUTING.md`](CONTRIBUTING.md) states what is checked by a validator
and what is checked by a person, so a contributor knows in advance which of their work is
subject to anyone's opinion. There is no CLA and no copyright assignment, so contributing
costs nothing that cannot be walked away from.

### 2.2 Public governance

Decisions that affect the shared universe follow a procedure that can be traced afterwards.

**Mechanism:** decisions of consequence are recorded in `docs/adr/` with the alternatives
that were rejected and why. Code records what, git records when; neither records why, and
why is what an audit needs. Discussion happens in public issues and pull requests.

This is currently a promise about how one person will behave. What makes it more than a
promise is that the record is public and permanent: a decision made without one is visibly
missing.

### 2.3 Technology is changeable

The engine, the SDK, the protocol and the architecture may all be replaced.

**Mechanism:** [ADR-0001](docs/adr/0001-engine-neutrality.md) states written exit criteria
for replacing the client, and `protocol/conformance/` is the executable test of them.
Anyone may build a replacement and demonstrate that it passes; **a proposal that meets the
exit criteria does not need the incumbent authors to agree with it.**

A claim of replaceability with no written exit criteria is not replaceability. That is why
the criteria exist as a document and as 27 vectors rather than as a sentence here.

### 2.4 Protection of existing work

Upgrades must consider the worlds, saves and contributions that already exist.

**Mechanisms**, all of which are already load-bearing rather than planned:

- Every protocol version bump ships its migration, and **a version bump proposed without
  one is not a valid proposal** ([SPEC §2.3](protocol/SPEC.md)).
- A save embeds the definition of every item it holds, so it survives its defining world
  being unpublished ([SPEC §8.3](protocol/SPEC.md)).
- A player keeps what they were carrying even when the world that defined it is gone. There
  is a test for this, because it is the case where the principle is easiest to violate by
  accident.

### 2.5 The constitution is amendable

Including this clause and the procedure in §5.

### 2.6 Independent forks

Anyone may take everything here and continue, under any name, for any purpose, without
asking.

**Mechanism:** 0BSD and CC0. No CLA to inherit, no scattered copyright to clear, no
attribution obligation to comply with, no relicensing fight available to anyone.
[`docs/SUCCESSION.md`](docs/SUCCESSION.md) §5 goes further: if the name cannot be
transferred, **a successor renames and that is the legitimate continuation, not a hostile
fork.**

## 3. Who decides

### 3.1 Now

The founding maintainer decides, and records decisions of consequence as ADRs.

This is not permanent authority and it is not a reward. It exists because a project with
nobody able to merge anything is not open, it is abandoned.

### 3.2 As soon as there is more than one **[dormant]**

`MAINTAINERS.md` lists maintainers with independent access — access that does not route
through any one person's account, since access that disappears with one person is not
independent access.

- **Two or more maintainers:** a change to the protocol, the licences, or this document
  needs a second maintainer's agreement, recorded on the proposal.
- **Three or more maintainers:** the founding maintainer's vote counts the same as anyone
  else's, and this clause stops being about them.

The targets, from [`docs/SUCCESSION.md`](docs/SUCCESSION.md) §3.1: a second maintainer
before the first community world is accepted, a third before any server holds player data.

### 3.3 What nobody may do, including the maintainer

1. **Revoke rights already granted.** Governance may change the licensing of future
   versions. It may not use that to take back what a published version already gave
   anyone. This is the one clause with no escape procedure: amending it does not reach
   versions already released, because those grants are not the project's to withdraw.
2. **Accept unreviewed external content into an official release.** Reviewed means the
   validator plus a person, per §2.1.
3. **Ship a protocol change without its migration** (§2.4).
4. **Remove this clause's first item.** It may be extended, not narrowed.

### 3.4 Absence

If the people holding the keys stop responding, [`docs/SUCCESSION.md`](docs/SUCCESSION.md)
§3.2 applies: 90 days of silence after three recorded attempts, a public declaration, 30
further days, and then the remaining maintainers may act with full authority. **[dormant]**
until a second maintainer exists — there is nobody to invoke it before then, and pretending
otherwise would be the theatre this document opened by refusing.

## 4. How a decision is made

1. **Propose** in a public issue or pull request, in whatever language you are comfortable
   with.
2. **Discuss** in public. A decision reached somewhere unreadable did not happen.
3. **Decide.** Per §3.
4. **Record.** Anything that would be expensive to re-litigate becomes an ADR, with the
   rejected alternatives. Anything smaller is the pull request itself.

## 5. Amendment

1. Open a pull request against this file. Say what changes and what it is for.
2. Leave it open for **14 days**, so that someone who reads the project weekly can still
   object.
3. Decide per §3, subject to §3.3.
4. Merge with the discussion linked from the commit.

This procedure amends itself by the same route. A shorter waiting period may be proposed,
but not applied to the proposal that shortens it.

One exception: a change that only corrects a typo, a broken link or a factual error about
what the code does may be merged immediately, and must say so in the commit message. Fixing
a wrong statement is not an amendment.

## 6. What this does not decide

Stated rather than left implied, because an unwritten gap eventually gets filled by whoever
is most confident.

- **Voting.** There is no membership roll, no eligibility rule and no voting mechanism.
  §3.2 is a stopgap that works for two or three people and will not work for thirty.
- **Money.** No business model, no contributor revenue share, no legal entity. See
  [README, *On commercialisation*](README.md#-on-commercialisation).
- **Moderation.** No code of conduct and no procedure for handling people. This is a gap,
  and it will be the first one that matters if anyone shows up.
- **Anything about your own copy.** Fork it, change it, sell it, delete this file. That is
  what §2.6 means.

## 7. Related documents

| Document | What it covers |
|---|---|
| [`docs/SUCCESSION.md`](docs/SUCCESSION.md) | What happens if the people holding the keys stop |
| [`CONTRIBUTING.md`](CONTRIBUTING.md) | How to contribute, and what is checked by whom |
| [`docs/adr/`](docs/adr) | Decisions of consequence, with rejected alternatives |
| [`protocol/SPEC.md`](protocol/SPEC.md) | The protocol, including the migration obligation |
| [`README.md`](README.md) | What the project is for |

---

*Creation belongs to everyone. This document exists so that it keeps belonging to everyone
after the person who wrote it stops.*
