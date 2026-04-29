# Tebay.dev Improvement Plan

Review date: 2026-04-24

This file tracks site improvements found during a source review of the current working tree. It includes the current content themes of the project pages so page-specific edits can be tracked without reopening every HTML file.

## Priority Tracker

Technical UX, accessibility, maintainability, and security hardening work has been moved to `technical_plan.md` so it can be implemented separately before the content pass.

### P0 - Broken or User-Visible Bugs

- [ ] Fix project demo video paths.
  - `projects/autorejection.html` uses `/videos/autorejection-prototype.mp4`.
  - `projects/microphonecontroller.html` uses `/videos/microphone-controller-demo.mp4`.
  - Current files live at `assets/images/autorejection-prototype.mp4` and `assets/images/microphone-controller-demo.mp4`.
  - Decide whether to move videos into a real `/videos/` directory or update the `data-video-src` values to `../assets/images/...`.
- [ ] Fix root-relative fetches if the site must work from `file://`, a preview subdirectory, or non-root deployment paths.
  - `blog.html` fetches `/blog/posts/manifest.json`.
  - `blog-post.html` fetches `/blog/posts/<slug>/index.html`.
  - `links.html` fetches `/links.json`.
  - Current behavior assumes the site is hosted at the domain root.
- [ ] Replace placeholder public data before launch or make empty states intentional.
  - `blog/posts/manifest.json` currently contains `Loading...`.
  - `links.json` currently contains `Loading...`.
- [ ] Add missing media for `Fly Fishing Game` or mark the page clearly as a WIP.
  - It is the only project page without screenshots, video, or a playable artifact.

### P1 - Content and Portfolio Impact

- [ ] Add a project index or featured projects section on the home page.
  - Current home copy explains the purpose of the site but does not give a direct path into the strongest work except through the nav.
- [ ] Add concise outcome summaries to each project page.
  - Examples: units sold, users helped, time saved, latency achieved, supported platforms, deployment footprint, reliability gains.
- [ ] Add clear status labels to projects.
  - Suggested values: `Production`, `Prototype`, `In progress`, `Archived`, `Internal tool`.
- [ ] Normalize project page structure.
  - Suggested order: Overview, Outcome, Screenshots/Demo, Stack, Challenges, Learnings, Key Systems/Features, Next Steps.
- [ ] Tighten copy where pages have strong technical detail but weaker reader framing.
  - `AutoRejection` and `WhisperTranscribe` are compelling but dense.
  - Add short "What problem did this solve?" and "What did I own?" sections.
- [ ] Add cross-links between related projects.
  - `WhisperTranscribe` already links to `MicrophoneController`.
  - `MicrophoneController` should link back to `WhisperTranscribe`.
  - `PersonalSite` should link to Blog and Links as live features.
- [ ] Add repository/live/demo links consistently.
  - Some pages have GitHub links, AutoRejection only has a prototype button, and Fly Fishing has no visual demo.

## Project Page Content Inventory

### AutoRejection

Current page content:

- Node-RED automation system with hardware integration and a custom dashboard UI.
- Describes a brewery can weight/rejection system built with MAP Equipment, Wild Goose Filling, and Bozeman-area breweries.
- Covers Raspberry Pi control, Wi-Fi UI, historical beer weight graphs, calibration, CSV export, AWS IoT OTA updates, RDS storage, custom load-cell PCB/firmware, ZYMKEY encryption/RTC, UL-listed stainless enclosure, and separate 5V/24V supplies.
- Visuals: front/top/back renders and load-cell PCB image.
- Action: prototype video button, currently pointed at `/videos/autorejection-prototype.mp4`.
- Stack: Node-RED, Node.js, JavaScript, Arduino, UIBuilder.
- Challenges: stable 50+ cans/min measurement/rejection, real-time Wi-Fi dashboard, AWS IoT/encryption complexity, brewery environment, custom PCB, partner/customer coordination, cost/manufacturability, premature security complexity.
- Learnings: simplify architecture, prototype rapidly, collaborate closely, balance performance/cost, defer security until useful, design for harsh environments, expect hardware market delays, account for supply-chain risk, document process, protect time in partnerships.
- Components/Hardware: Node-RED flows, standalone/Wild Goose variants, custom JS, UIBuilder dashboard, AWS IoT, pneumatic rejection, Arduino load-cell PCB, Raspberry Pi, UL enclosure, ZYMKEY.

Improvement tasks:

- [ ] Add a short outcome block: number of units sold, Wild Goose adoption, target line speed, and what role you owned.
- [ ] Fix prototype video path.
- [ ] Clarify the sentence "Communicated with a load cell..." into first-person ownership and complete grammar.
- [ ] Consider splitting business lessons from technical learnings for readability.

### DBFirstDataGrid

Current page content:

- Full-stack equipment management dashboard with a database-driven data grid.
- React + Express dashboard where the server inspects database schema metadata and returns typed field descriptors so the frontend can build headers, forms, and dropdowns without hardcoded field knowledge.
- Supports nested subgrids, paginated fetching, add-record modal, and SQLite/MySQL switching.
- Stack: React 17, Express 4, SQLite, MySQL, Podman, Node.js, ES Modules.
- Challenges: dynamic SQL identifier safety, recursive unknown-depth subgrids, SQLite/MySQL dialect compatibility, live database tests with isolated in-memory SQLite.
- Learnings: schema-driven UI needs a clear contract, dynamic identifiers need allowlisting, test DB schema parity matters, early containerization avoids environment-specific bugs.
- Key features/API: schema-driven UI, recursive relational subgrids, strict allowlist/regex validation, Podman Compose, test suites, endpoints for fetch, fields, distinct values, add, update, delete.

Improvement tasks:

- [ ] Add screenshots or a short screen recording of the data grid and add-record modal.
- [ ] Add an outcome statement: what equipment workflow it supports and why schema-driven UI mattered.
- [ ] Show one small schema-to-UI example to make the core idea immediately understandable.

### Fly Fishing Game

Current page content:

- 16-bit style 2D fly fishing simulation set on the Madison River, Montana, built in Godot 4.
- Covers hatch-driven fish behavior, directional vision cones, edge feeding, skill-based casting, false-cast rhythm, side-scrolling river cross-section, depth layers, hydraulics, boulders, and eddies.
- Describes seeded procedural river generation with FastNoiseLite, depth profiles, rocks, boulders, eddy currents, island generation, hold scoring, depth-field rendering, blur passes, wake zones, caustic sparkle, and difficulty tiers.
- Initial scope targets the Mother's Day Caddis hatch.
- Stack: Godot 4, GDScript, SQLite, godot-sqlite, FastNoiseLite, Podman.
- Challenges: realistic procedural hydraulics, 2D depth-field rendering, fish spook logic, casting state machine, infinite procedural section streaming.
- Learnings: central SpookCalculator helps tuning, Godot `_draw()` needs batching, data/render separation enables testing, GDD planning limits scope creep.
- Key systems: RiverGenerator, RiverRenderer, CastingController, SpookCalculator, FishAI, HatchManager, DatabaseManager, section streaming.
- Platforms: Linux, Windows, Android planned, iOS planned.

Improvement tasks:

- [ ] Add screenshots, GIF, video, or embedded playable build.
- [ ] Add current status and next milestone.
- [ ] Add a short "why this is interesting" intro for non-anglers.
- [ ] If still early, label as `In progress` so the lack of demo feels intentional.

### MicrophoneController

Current page content:

- Two-button USB HID microphone controller with tap-to-toggle and push-to-talk.
- Describes game/communication app use cases with multiple mic channels, keyboard/gamepad HID mode switch, and visible channel state.
- Connects to WhisperTranscribe as a physical control surface for transcription vs AI command mode.
- Visuals: assembled and internal hardware photos.
- Action: demo button, currently pointed at `/videos/microphone-controller-demo.mp4`.
- Stack: Arduino C++, ATmega32U4, USB HID, AVR core, arduino-cli.
- Challenges: keyboard HID interference with controller detection; AI-generated hold/toggle implementation had to be rewritten manually.
- Learnings: single toggle state is cleaner; mode switch changes active USB interface without device reinitialization.
- Hardware/Button behavior: nullbits Bit-C PRO, D2/D3 buttons, D4/D5 LEDs, D15 mode switch, Scroll Lock/Pause keys, gamepad buttons 8/9, tap/hold behavior.

Improvement tasks:

- [ ] Fix demo video path.
- [ ] Link back to `WhisperTranscribe`.
- [ ] Add a wiring diagram or simple schematic.
- [ ] Add build/use instructions or a concise "how it works" flow.

### WhisperTranscribe

Current page content:

- GPU-accelerated push-to-talk transcription and voice command daemon.
- Driven by MicrophoneController. Scroll Lock transcribes into the focused window via ydotool; Pause sends text to a configurable LLM for executable actions.
- Covers evdev exclusive keyboard grab, tap guard, whisper.cpp Vulkan GPU transcription, systemd user service, GTK3 system tray, settings dialog, Ollama/Claude backends, binary/audio/language/timeout/terminal configuration.
- Visuals: tray settings and advanced settings screenshots.
- Stack: Python 3.14, whisper.cpp, Vulkan, python-evdev, PipeWire, ydotool, Ollama, Claude, GTK3, D-Bus, systemd, pytest.
- Challenges: backend API differences, low-latency whisper.cpp pipeline, robust keyboard grab/error recovery, GTK3 tray settings.
- Learnings: audio/GPU transcription, multi-LLM interface, Python process/systemd programming, Linux tray standards are fragmented.
- LLM command mode: parses `GUI:`, `TERMINAL:`, and `KEYS:` responses.
- System tray: KDE StatusNotifierItem + DBusMenu, service polling, GNOME AppIndicator requirement.
- Components: key_watcher, recorder, transcriber, commander, typer, tray, daemon.
- Work in progress: Ubuntu/Debian support, PulseAudio fallback, NVIDIA/CPU whisper.cpp builds, WAV finalization fix, keyboard enumeration refactor.
- Hardware: MicrophoneController and AMD Radeon RX 7900 XTX.

Improvement tasks:

- [ ] Add a short demo video or animated workflow.
- [ ] Add measured latency or hardware performance notes.
- [ ] Add safety framing for LLM command execution.
- [ ] Clarify install/platform support status and whether Python 3.14 is required or simply current dev environment.

### PersonalSite

Current page content:

- This site: personal portfolio and documentation platform built from scratch with vanilla HTML, CSS, and JavaScript.
- Describes using Claude Code heavily to design, implement, and document the site.
- Requirements: no frameworks/build tools, AWS Lambda free-tier hosting, lightweight CMS for blog/links, responsive and performant UX, AI-assisted development.
- Covers Lambda/container deployment, CGI, S3-backed blog/links, admin panel, AWS automation, Lambda gotchas, and AI-assisted coding limits.
- Stack: HTML5, CSS3, Vanilla JS, Shell/CGI, BusyBox httpd, AWS Lambda, S3, CloudFront, Podman.
- Challenges: Lambda read-only filesystem, MinIO client/STSes, Lambda memory/CPU, S3 sync/readiness timeout, manifest JSON comma bug.
- Learnings: Lambda + CGI fit, 6 MB payload limit affects video, Claude Code strengths/weaknesses, AWS CLI safest for STS, CPU scales with Lambda memory, placeholder manifests prevent blank pages.
- Key features: shared layout script, theme picker, blog draft/publish/WIP/image uploads, links CMS, cookie session auth, POSIX shell CGI, S3-backed cache, cold-start sync.

Improvement tasks:

- [ ] Add screenshots of the admin editor, links manager, and theme picker.
- [ ] Add a small architecture diagram or request flow.
- [ ] Update the theme localStorage key description to match the implementation.
- [ ] Link to live Blog and Links features from this page.

## Site-Wide Content Notes

- The overall voice is personal and technically credible. Keep that tone.
- The strongest differentiator is not "I used these tools"; it is "I built useful systems across hardware, automation, infrastructure, and desktop tooling." Make that clearer near the top of the home page.
- The projects are richer than the navigation suggests. A featured section with 3-4 cards would help first-time visitors understand the range quickly.
- Several pages would benefit from a one-sentence "result" directly under the tagline.
- Add dates or time periods where appropriate; it helps readers understand project maturity and career arc.

## Content Validation Checklist

- [ ] Confirm every project page has a clear problem, ownership, outcome, and current status.
- [ ] Confirm project page structure is consistent enough to scan quickly.
- [ ] Confirm screenshots, demos, or WIP labels support the story of each project.
- [ ] Confirm Blog and Links do not ship placeholder content.
- [ ] Confirm home page copy gives first-time visitors a direct path into the strongest projects.
- [ ] Confirm project cross-links are useful and not repetitive.
