# Succession: what happens if the founding maintainer stops

**Status:** Active. Written 2026-09-19, while the project has exactly one maintainer —
which is the only honest time to write it.

The README says founder authority "is not permanent." That is a promise, and a promise
with no mechanism is a wish. This document is the mechanism.

---

## 1. The honest part first

Right now there is one person. **Governance procedures do not enforce themselves when
there is nobody to enforce them.** An inactivity clause with a 90-day timer is worth
nothing if, on day 91, no second person exists to invoke it.

So the measures below are sorted by *when they actually start working*, not by how
impressive they sound. Everything in §2 works today, with one person, and does not depend
on anyone's goodwill after that person is gone. Everything in §3 and §4 is inert until
there are two or three people, and saying otherwise would be theatre.

---

## 2. Works today, with one maintainer

### 2.1 The licence is already the strongest succession mechanism this project has

0BSD for code and CC0 for assets and documents is not only a generosity decision. It is a
**continuity decision**, and it pre-empts the way most solo-founder open-source projects
actually die:

| Common failure | Why it cannot happen here |
|---|---|
| Copyright is scattered across contributors; nobody can relicense or clarify terms | 0BSD and CC0 require no permission from anyone, for anything |
| A CLA or copyright assignment sits with one person or a dormant company | There is no CLA and no assignment to inherit |
| A successor cannot legally ship a commercial fork | 0BSD and CC0 both permit it unconditionally |
| Attribution obligations pile up until compliance is impractical | 0BSD imposes no attribution requirement; CC0 waives rights as far as law allows |
| The project is relicensed out from under the community | Already-published versions cannot be un-granted (see README, *License*) |

Anyone may take everything here and continue, under any name, for any purpose, without
asking. That is the floor, and the floor is already poured.

### 2.2 The protocol is the succession document

A successor does not need to understand the founder's Godot code. They need
[`protocol/`](../protocol): a written specification, three schemas, and 27 conformance
vectors that say exactly what correct behaviour is.

**The tests are the knowledge transfer.** A new maintainer can rewrite the client, the
server, or both, and know they got it right, without ever speaking to the person who left.
This is the same property that makes the engine replaceable
([ADR-0001](adr/0001-engine-neutrality.md)) — it is one mechanism serving two purposes.

### 2.3 ADRs record *why*, which is what dies with a person

Code records what. Git records when. Neither records why, and why is the thing a successor
most needs and can least reconstruct. Every decision that would be expensive to re-litigate
goes in `docs/adr/` with its rejected alternatives.

### 2.4 No single point of storage — **open gap**

> **Current risk, highest severity:** at the time of writing, this repository exists on one
> laptop. That is a worse single point of failure than any governance problem in this
> document, and it is fixable in ten minutes.

Requirements:

- The canonical history MUST live in at least **two independently operated public hosts**
  (e.g. one large forge plus one unaffiliated mirror). Two accounts on the same host is one
  host.
- Any self-hosted machine is a **convenience, never the source of truth**. Hardware in
  someone's home disappears when they move, lose interest, or lose power.
- Mirrors MUST be pushed by the same command that pushes the primary, so they cannot
  silently rot. A mirror nobody checks is a mirror that is out of date.

### 2.5 Reproducible from zero — **open gap**

Anyone must be able to go from a clean clone to a running client, a running server, and
passing tests using only written commands, on a machine that has never seen this project.

The test is not "the instructions look complete." The test is running them on a clean
checkout and fixing whatever breaks. Undocumented environment knowledge is the most common
way a project becomes unmaintainable while looking perfectly healthy.

### 2.6 Infrastructure inventory — **open gap**

`docs/INFRASTRUCTURE.md` must list every external thing the project depends on: domains,
hosts, CI, registry accounts, and who holds each one. **No secrets** — an inventory, so a
successor knows what exists and what they will have to replace.

For anything that cannot be transferred, the answer is written down in advance: the
successor replaces it. Which leads to §5.

---

## 3. Starts working at two or three people

### 3.1 Standby maintainers

`MAINTAINERS.md` names people with independent push access to the canonical repository and
to at least one mirror. Target: **a second person before the first community world is
accepted, a third before any multiplayer server holds player data.**

Independent means their access does not route through the founder's account. Access that
can be revoked by one person's absence is not independent access.

### 3.2 Inactivity procedure

When at least two maintainers exist:

1. **Trigger.** No response on any project channel for **90 days**, after three attempts
   spaced at least seven days apart, recorded publicly.
2. **Declaration.** Any maintainer opens a public issue recording the attempts, and waits
   **30 further days**.
3. **Effect.** After 120 days total, the remaining maintainers may act with full authority:
   release, accept changes, and add maintainers.
4. **Return.** An absent maintainer who returns is reinstated as a maintainer, but does not
   automatically regain sole decision authority. Continuity outranks seniority.

The timers are deliberately slow. The cost of acting 120 days late is an inconvenience; the
cost of acting wrongly on someone who was merely ill is a project split.

---

## 4. Starts working with a community

Full governance — membership, proposals, amendments, dispute resolution — lives in
`CONSTITUTION.md`. This document only covers the failure mode where the people currently
holding the keys stop showing up.

---

## 5. If the name cannot be transferred

A domain or an account may be unrecoverable: no access, no response, no legal route.

**Then the successor renames, and that is the legitimate continuation.** It is not a
hostile fork and it is not a lesser project.

Under 0BSD and CC0 there is nothing to negotiate: the code, the protocol, the worlds and
the documents all travel with whoever picks them up. The only thing a name change costs is
search results. Continuity of the work outranks continuity of the label — and any reading
of this project's own constitution that says otherwise is the wrong reading.

---

## 6. Checklist

Ordered by how much risk each one removes today.

- [ ] **Push to two independently operated public hosts** (§2.4) — highest severity open item
- [ ] **Verify the bootstrap instructions on a clean checkout** (§2.5)
- [ ] `docs/INFRASTRUCTURE.md` inventory, no secrets (§2.6)
- [x] Licences that need no permission to continue under (§2.1)
- [x] Executable protocol specification with conformance vectors (§2.2)
- [x] ADRs recording rejected alternatives (§2.3)
- [ ] `MAINTAINERS.md` with a second person (§3.1)
- [ ] Inactivity procedure adopted once a second maintainer exists (§3.2)
- [ ] `CONSTITUTION.md` (§4)
