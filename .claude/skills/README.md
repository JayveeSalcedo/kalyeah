# KalyeAh project skills

These project-local Claude skills encode the specialist workflows used to change KalyeAh without broadening its scope or weakening its architecture. Each skill reads `CLAUDE.md` first; that file remains the source of truth.

| Skill | Owns | Does not own |
| --- | --- | --- |
| `gameplay-simulation` | Agawan Base rules, deterministic simulation, weapon behavior, input semantics | Network transport, presentation, export settings |
| `authoritative-multiplayer` | WebSocket protocol, rooms, server authority, snapshots, reconnects | Game balance, animation, Android rendering |
| `gameplay-presentation` | Animation, camera, VFX/audio hooks, HUD feedback, sim-to-view mapping | Simulation outcomes, protocol, asset creation |
| `android-performance` | Profiling, mobile budgets, touch/safe areas, Android and web compatibility | Game rules, networking semantics, art direction |
| `game-qa-release` | Risk-based tests, regression coverage, validation, PR and release readiness | Product scope, feature implementation, manual version edits |

The boundaries are deliberate. Multiple agents may use these skills at the same time when their file ownership does not overlap. If a task crosses boundaries, split it into commits and let the owning specialist review each part.

Do not install generic skill bundles, editor-control MCP dependencies, custom Godot forks, or alternate test frameworks for this project. Add a skill only when it gives a repeatable workflow that `CLAUDE.md` and these five skills do not already cover.
