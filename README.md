# OpenVerse 🌌

**English** · [简体中文](README.zh-CN.md) · [Русский](README.ru.md) · [日本語](README.ja.md)

### An open-source game universe created by everyone, developed with AI, and able to evolve itself.

**Open Source · AI Native · Community Driven · Infinite Possibilities**

> We are not here to imagine every world on everyone's behalf.
>
> We want to build a system in which anyone's world can be born, run, connect, and endure.

---

## 🌍 What is OpenVerse?

OpenVerse is an open-source game and community experiment being built from scratch.

Our goal is not to ship a game with fixed content. It is to create an open-world universe that the community builds together and keeps expanding.

Here you can:

* Live, farm, fish, and build a home, the way you would in a life simulation game.
* Create a cultivation world with sects, alchemy, and flying swords.
* Build a cyberpunk city and explore artificial intelligence and future technology.
* Found an interstellar civilization and explore the cosmos.
* Design entirely new physical laws, social systems, and game mechanics.
* Create a world none of us can imagine today.

These are examples, not a list of permitted genres.

**Worlds should be imagined by their creators, not prescribed in advance by the project's founders.**

We want everyone to be able to turn their imagination into real, playable content with the help of AI.

---

## ✨ Core Principles

### 1. Anyone can create

You do not need to be a professional programmer.

You can propose ideas, design mechanics, draw maps, compose music, hunt bugs — or write code with AI.

It can begin with a single sentence:

> I want to create a cultivation world with sects, spiritual roots, alchemy, and heavenly tribulations.

Through AI-assisted development, modular tooling, and community collaboration, we hope to gradually turn ideas like this into worlds that actually run.

AI lowers the barrier to creation.

The community is what makes creations last.

### 2. No mandated genre or worldview

OpenVerse will not confine every world to a single kind of gameplay.

One world may have levels, combat, and magic.

Another may have no combat at all, and let players only farm and make friends.

Creators define the rules of their own worlds.

Worlds can connect to one another through shared protocols, without being required to share identical mechanics or economies.

### 3. Open source and built together

We plan to open the game code, the world development tools, the associated protocols, and the governance rules.

Community members can propose changes, submit code, fix problems, develop new systems, and take part in governing the project.

Open source does not mean unreviewed code goes straight into the live game.

All publicly released code and content should pass review, testing, and licence checks proportional to its risk.

### 4. AI-native development

AI will be used for more than generating assets. It will take part in the full software development process:

* Turning natural-language ideas into development tasks.
* Generating code and tests.
* Helping analyse architecture and compatibility.
* Checking for potential defects and security risks.
* Generating technical documentation.
* Assisting with adaptation and migration between worlds.

AI is a development assistant, not an administrator with unlimited authority.

Changes touching core architecture, security, player data, or official releases must follow the project's governance and review process.

### 5. Every technical choice can be revisited

The game engine is not permanent.

The SDK is not permanent.

The world protocol is not permanent.

Even the project's governing constitution is not permanent.

Following the governance procedure in force at the time, the community can propose, deliberate on, and carry out changes.

We will not require every future creator to obey a technology forever, merely because it happened to be used first.

**Tools should serve creation, not constrain it.**

---

## 🪐 One universe, countless worlds

OpenVerse aims to build an extensible system of worlds.

```text
                  OpenVerse
                      |
             Shared Universe Services
                      |
       +--------------+--------------+
       |              |              |
  Pastoral World  Cultivation     Cyber World
       |            World             |
  Community        |              Community
   Content     Community           Content
                Content

              +-------+
              |
          New worlds...
```

Different worlds can have their own rules, maps, saves, and mechanics.

The shared universe services handle only what must be shared: identity, world discovery, travel, and cross-world collaboration.

Items and abilities that cross worlds must obey the rules of the destination world.

For example, a flying sword from a cultivation world may exist as a decoration in a pastoral world, but it should not automatically gain the right to destroy other players' buildings.

These interoperability features will be developed step by step, not all at once in the first release.

---

## 🛠️ World SDK: let anyone create a world

We plan to develop a World SDK so that creators can build and plug in new worlds in a modular way.

The SDK will gradually provide:

* World registration and loading.
* World entrances and travel.
* Per-world data and saves.
* Communication between worlds.
* Identifiers for resources and items.
* Permission management.
* Version compatibility and migration.
* Automated testing and release pipelines.

The SDK itself is part of the project that the community can change.

If the existing SDK cannot support a new kind of gameplay, the community can propose extending it, modifying it, or replacing it.

We will not attempt to design a supposedly perfect universal SDK up front.

In the first phase we will build several small worlds for real, and let the interfaces emerge from that practice.

---

## 📜 The OpenVerse Constitution

OpenVerse intends to build an open, transparent, and amendable system of community governance over time.

The initial draft constitution will address the following principles:

**Open creation**

Anyone can propose ideas, development plans, and improvements.

**Public governance**

Decisions that affect the shared universe should follow a clear and traceable procedure.

**Technology is changeable**

The game engine, SDK, core protocols, and technical architecture can all be changed through the applicable procedure.

**Protection of existing work**

Major upgrades must take existing worlds, player data, and contributors' work into account, and provide a reasonable path for compatibility, migration, or rollback.

**The constitution is amendable**

The community can amend the constitution — including the amendment procedure itself — under the amendment procedure in force at the time.

**Independent forks**

Within the terms of the licences it adopts, the project must make clear what modification, redistribution, and independent deployment are permitted.

Until the community governance system exists, the founding maintainers are temporarily responsible for project bootstrapping, security review, and releases.

This is not permanent authority.

The project needs to establish clear membership, decision procedures, transfer of authority, and dispute resolution over time.

Governance documents are maintained separately:

`CONSTITUTION.md`

The constitution is still a draft, and the voting mechanism has not been decided.

---

## 🚧 Current status

**Status: Pre-Alpha / project bootstrap**

OpenVerse is being developed from zero. We are building a minimal runnable prototype.

Please note:

* There is no finished open-world game yet.
* The general-purpose World SDK is not finished.
* There is no AI development platform online.
* There is no formal community voting or governance system yet.

All of the above are plans, not completed work.

We will publish actual development progress, known issues, and interim results as openly as we can.

---

## 🎮 The first playable version

### OpenVerse 0.0.1

Our first development goal is:

**One village, one cultivation world, one portal.**

Phase 1 plans to deliver:

* The player can move freely in the starting village.
* The player can enter the cultivation world through a portal.
* The player can obtain a spirit herb in the cultivation world.
* The player still holds that item after returning to the village.
* Data for both worlds loads and saves correctly.
* Worlds use a first, modular structure.

On top of that, we will try to let a new contributor create a third world with AI and, after review, connect it to the game.

The first version is not about a large map or rich content.

What it has to prove is this:

**Can a new world be created, and actually join this universe?**

The initial prototype will likely be 2D and single-player, to keep complexity low. That is not a permanent commitment about the game's dimensionality, visual style, or multiplayer capability.

---

## 🗺️ Roadmap

### Phase 0: Bootstrap

* [ ] Set up a public repository
* [ ] Write the project README
* [ ] Draft the initial constitution
* [ ] Decide the code and asset licences
* [ ] Write contribution guidelines and code review rules
* [ ] Set up the base game project

### Phase 1: Minimal open universe

* [ ] Create the starting village
* [ ] Implement player movement and interaction
* [ ] Create the cultivation world
* [ ] Implement cross-world travel
* [ ] Implement basic items and saves
* [ ] Write basic tests

### Phase 2: Community world expansion

* [ ] Extract the world integration interface
* [ ] Build the first World SDK
* [ ] Provide world development examples
* [ ] Set up automated code review
* [ ] Accept the first community world
* [ ] Validate that the SDK actually extends

### Phase 3: Multiplayer open world

* [ ] Research and implement network synchronisation
* [ ] Develop the world server
* [ ] Implement shared multiplayer building
* [ ] Implement player identity and cross-world migration
* [ ] Build basic community moderation features

### Phase 4: AI creation platform

* [ ] Generate development plans from natural language
* [ ] AI-assisted creation of world modules
* [ ] Automated builds and isolated testing
* [ ] Community review and release
* [ ] In-game world creation entry point

### Phase 5: Open governance

* [ ] Finalise community membership rules
* [ ] Establish proposal and amendment procedures
* [ ] Keep a public record of decisions
* [ ] Transfer governance authority where appropriate

The roadmap is not a fixed promise. The community can change direction based on real progress and the governance procedure.

---

## 🤝 How to take part

We welcome contributions of every kind.

You can:

**Propose ideas**

Design a new world, new mechanics, or new rules for the universe.

**Develop**

Submit code, whether written with AI or by hand.

**Make content**

Contribute maps, buildings, art, music, and stories that you have the right to license.

**Test the game**

Find bugs, report performance problems and rough edges.

**Improve the architecture**

Propose improvements to the SDK, protocols, servers, and development tools.

**Take part in governance**

Discuss the project's rules, submit constitutional amendments, and participate in community governance once it is established.

Until formal contribution guidelines are published, please raise ideas through GitHub Issues.

Code contributions should be submitted as pull requests and go through review.

Please do not submit unlicensed third-party code, game assets, or personal data to the project.

Large volumes of unfiltered AI-generated content should not go straight into the main branch.

Future contribution rules will be documented in:

`CONTRIBUTING.md`

---

## 🔒 Security and quality

Open creation does not mean open, unlimited privilege.

The project plans to use layered review:

1. Static code and dependency analysis.
2. AI-assisted code review.
3. Automated functional and compatibility testing.
4. Human maintainer review where required.
5. Isolated builds, testing, and staged releases.

Unapproved external code must not run directly on official game servers.

Core systems, player saves, and sensitive data require stricter access control.

AI review cannot replace the whole of security review.

For higher-risk changes, we will prioritise protecting the runtime environment and player data.

---

## 💡 On commercialisation

OpenVerse wants to find a model that can sustain open-source development and community operations over the long term.

That may eventually include official servers, sponsorship, hosting services, and AI creation services.

No specific business model, contributor revenue share, or legal entity has been decided.

Any such plan should be discussed publicly before it is put into effect, and should make clear how project assets, contribution licensing, operational responsibility, and revenue are handled.

Commercial operation must not be used to quietly strip away open-source rights already granted to the community.

---

## ⚖️ License

OpenVerse aims to maximise freedom to create, modify, distribute, and commercialise.

The project uses the following licensing scheme:

* Game source code, SDK, and development tools: **0BSD License**
* Original art, music, and other non-code assets that the project fully owns the rights to: **CC0 1.0 Universal**
* The project constitution and original documentation: **CC0 1.0 Universal**

Third-party dependencies and assets remain under their own licences and are not automatically covered by the above. Contributors must ensure they have the right to submit content under the corresponding licence.

Anyone may use, modify, distribute, commercialise, or fork OpenVerse within the terms of the applicable licences.

We encourage voluntary attribution, giving back to the community, and publishing improvements, but none of these are additional legal conditions of the licences above.

OpenVerse governance may change the licensing arrangements of future versions, but it may not use that to revoke rights already validly granted in existing versions.

**Creation belongs to everyone.**

See [`LICENSE`](LICENSE) (0BSD) and [`LICENSE-CC0`](LICENSE-CC0) (CC0 1.0 Universal).

---

## 🌱 Starting from zero

OpenVerse is still only a project that has just begun.

We have no vast universe already built, and we do not claim AI will automatically solve every development problem.

We want to build this system step by step, through real development, repeated failure, and open collaboration.

The first step is to build one portal.

The second is to let someone else create a new world.

After that, to let more and more creators take part — and gradually hold the right to decide this universe's future.

---

## 🌌 Our Vision

**A universe built by everyone, powered by AI, governed by its community, and free to evolve.**

**The universe is not finished. It is waiting for its creators.**
