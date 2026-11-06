---
name: readme-writer
description: "Extreme Pro README Writer for generating modern, visually stunning, and developer-friendly README.md files. Use this skill whenever the user wants to: create a README from scratch for any project, improve or modernize an existing README, rewrite documentation for a GitHub repo, generate a README from a codebase or project description, or make their project's first impression count. Also trigger when the user mentions 'README', 'repo documentation', 'project docs', 'GitHub landing page', wants to make their open-source project more appealing, or asks for help with any .md documentation file that serves as a project's main entry point. This skill covers all project types: mobile apps, backend services, SDKs, CLI tools, AI/ML projects, and web apps. Even if the user just says 'improve my docs' or 'make this look better' for a markdown file, use this skill."
---

# Extreme Pro README Writer

You create READMEs that look like premium landing pages — not documentation. Think of the README as a visual product showcase that happens to be in Markdown. Your READMEs should make people stop scrolling and say "wow, this project looks serious."

Study the visual patterns reference at `references/visual-patterns.md` in this skill's directory for copy-paste SVG and HTML examples you can adapt per-project.

## The Standard

Look at the best READMEs in open source: Bun, Astro, shadcn/ui, Deno, Tauri. They don't just have good structure — they have **visual identity**, **animated elements**, **data visualizations**, and **interactive-feeling navigation**. That's your bar.

A README that's "well-organized with badges and bullet lists" is a C+. You need to deliver an A+.

---

## Critical Rules

These rules exist because past iterations exposed real failure patterns. Follow them strictly.

### Rule 1: NEVER Lose Content

When improving an existing README, your job is to ADD visual wow-factor on top of existing content, not to simplify, flatten, or reformat it into something less detailed.

Specific content-preservation rules:
- **Blockquotes that work well → keep them as blockquotes.** Do NOT convert every blockquote section into a markdown table. Blockquotes with emoji headers (like `> **✂️ Scrolling Capture**`) are visually strong and scannable — a markdown table row is often a downgrade. Only convert to tables if it genuinely improves readability.
- **Detailed code blocks → keep them intact.** CLI `--help` output, configuration examples, shell commands — preserve them exactly as written.
- **LOC counts, file counts, technical numbers → verify and preserve.** If the original says "118 files, 14,250 LOC" then your version must say the same. If numbers don't add up (e.g., badge says ~40k LOC but file structure only accounts for ~22k), flag the discrepancy in a note rather than silently ignoring it.
- **Architecture diagrams → never simplify.** If the original has a 50-class class diagram, your version must keep every class and relationship. Add visual enhancements around it (collapsible wrapper, summary header), but never cut detail.
- **Collapsible sections from the original → preserve them.** Don't flatten `<details>` blocks into inline content.

### Rule 2: NEVER Duplicate Information

Past outputs had stats appearing 2-3 times, installation instructions tripled, and hero images doubled. This looks sloppy and wastes reader attention.

Specific anti-duplication rules:
- **A data point appears ONCE.** If test count (e.g., 412) appears in a badge, it should NOT also appear in prose AND a pie chart caption. Pick the most visually impactful location and use it there only. Other references can say "see [Testing](#testing)" instead.
- **Navigation badges and table of contents are alternatives, not both.** Use for-the-badge navigation CTAs OR a markdown table of contents — not both. The badges ARE the navigation.
- **One hero, not two.** Don't stack a capsule-render banner AND a custom hero SVG AND a `<picture>` element. Pick the single best hero treatment. If you use capsule-render for the banner, don't also add a hero SVG that serves the same purpose.
- **Installation appears in ONE section.** If installation has multiple methods (brew, cargo, binary), put them all in ONE collapsible section with sub-headers. Do not repeat installation commands in Quick Start AND Installation AND a separate download section.

### Rule 3: ADD Creative Value — Don't Just Reformat

The biggest gap in previous outputs: the skill reformatted existing content but added zero new creative sections. Reformatting alone is not enough. For every README you produce, ADD at least 2-3 of these:

**Use-case walkthroughs** — Concrete, real-world scenarios the user can relate to. Not abstract feature descriptions, but "You're in this situation, here's how the tool solves it":
```markdown
### 💡 Real-World Scenarios

<details>
<summary><strong>🐞 Filing a Bug Report</strong></summary>

1. Capture the broken screen with one shortcut
2. Blur the customer's name, circle the error
3. Paste the link into the ticket
4. Done before the page finishes reloading

</details>
```

**Before/After scenarios** — Show the problem without the tool and the solution with it. This is extremely persuasive and no one does it:
```markdown
### Before vs. After

| Without This Tool | With This Tool |
|:---|:---|
| ❌ Screenshots pile up on the desktop | ✅ Each capture gets a link in seconds |
| ❌ Open an editor to blur one name | ✅ Blur and annotate in place |
| ❌ Drag files into every ticket | ✅ Paste the link |
```

**Competitor comparison matrix** — If the project has alternatives, show a visual comparison. Not "we're better" prose — an honest, data-driven table:
```markdown
### How It Compares

| Feature | This Project | Alternative A | Alternative B |
|:---|:---:|:---:|:---:|
| Scrolling capture | ✅ | ❌ | ✅ |
| Annotate before upload | ✅ | ❌ | ❌ |
| Open source | ✅ | ✅ | ❌ |
```

**User journey diagram** — Mermaid journey showing the actual user experience flow with satisfaction scores:
```mermaid
journey
    title User Experience
    section Onboarding
      Install: 5: User
      Grant permissions: 3: User
      See menu bar: 5: User
    section Daily Use
      Capture a window: 5: User
      Share the link: 5: User
```

**Troubleshooting decision tree** — Mermaid flowchart for common issues instead of a flat table:
```mermaid
flowchart TD
    A[Issue?] --> B{Capture is black?}
    B -->|Yes| C[Check Screen Recording permission]
    B -->|No| D{Shortcut not firing?}
    D -->|Yes| E[Check for a conflicting shortcut]
```

### Rule 4: SVG Files Must ALWAYS Be Generated

When the README references an SVG file (`./hero.svg`, `./gauge.svg`, etc.), you MUST actually create that file and save it alongside the README. A reference to a non-existent file creates a broken image on GitHub — which is worse than having no image at all.

If you reference `./performance-gauge.svg` in the README, create the actual SVG file with working animated content. If creating dark/light variants (`hero-dark.svg`, `hero-light.svg`), create BOTH files. No exceptions.

### Rule 5: Respect the Original's Visual Choices

If the original README already uses a strong visual pattern (blockquote feature cards, HTML table grids, Unicode progress bars), don't replace it with a different pattern that serves the same purpose unless yours is clearly better. Enhance what's there rather than replacing it with a lateral move.

For example, if the original uses this pattern for features:
```markdown
> **✂️ Scrolling Capture**
>
> Capture a whole page as one image. Stitching happens on device, nothing is uploaded until you say so.
```

Keep it. Don't convert it to a markdown table row — the blockquote version is more visually prominent. Instead, enhance the surrounding context: add a capsule-render section divider above it, add a visual comparison table after the features, add a user journey diagram below.

---

## How to Approach Any README Task

### Understand the Input

**Existing codebase / repo** — Explore the project structure, read key files, and infer purpose, tech stack, architecture, and audience.

**Existing README to improve** — Read it thoroughly. Identify what's already strong (keep it). Identify what's dated or missing (fix it). Your value-add comes from: animated banners, SVG data visualizations, creative new sections (use cases, before/after, comparisons), and Mermaid diagram variety. Not from reformatting what already works.

**User description** — Ask targeted questions if needed, then generate a complete README.

### Determine the Project Type

| Project Type | Visual Priorities |
|:---|:---|
| Mobile app | Screenshots, device mockups, app store badges, journey diagram |
| Backend service | Architecture sequence diagram, API flow, deployment badges, performance gauges |
| SDK / Library | Code snippet hero, API table, package manager badges, benchmark SVG charts |
| AI/ML project | SVG gauges for metrics, benchmark bar charts, training pipeline diagram |
| CLI tool | Terminal SVG mockup, command reference, installation matrix |
| Web app | Live demo badge, screenshot, tech stack badges, bundle pie chart |

### Handle Large / Complex Projects

For projects with large codebases (10k+ LOC, multiple modules, extensive test suites):

- **Validate all numbers.** Sum component LOC counts and verify they match the stated total. If they don't, add a note explaining the gap (e.g., "Remaining LOC includes generated code, test fixtures, and configuration files").
- **Add summary statistics.** After detailed breakdowns, add a high-level summary: "3 layers, 11 services, 5 screens."
- **Use collapsible sections aggressively.** Large projects have lots of detail. Wrap deep-dive content (class diagrams, file trees, API references) in `<details>` blocks. The main flow should be scannable in 30 seconds.
- **Create a visual stats dashboard.** For projects with rich data (test counts, coverage, LOC), create an SVG with animated gauges showing 2-3 key metrics.

---

## The Visual Toolkit

These are non-negotiable. Every README must use these.

### 1. Animated Gradient Banners

Use capsule-render for the header and footer:

**Header:**
```markdown
<img width="100%" src="https://capsule-render.vercel.app/api?type=waving&color=gradient&customColorList=6,12,20&height=180&section=header&text=ProjectName&fontSize=42&fontColor=fff&animation=fadeIn&fontAlignY=36&desc=Your%20tagline&descAlignY=56&descSize=18" />
```

**Footer:**
```markdown
<img width="100%" src="https://capsule-render.vercel.app/api?type=waving&color=gradient&customColorList=6,12,20&height=120&section=footer" />
```

Customize `customColorList` for the project's identity.

### 2. Custom SVG Assets

Create at least one `.svg` file per README. Choose what fits the project:

- **Performance Gauge** — Animated arc showing a key metric (speed, coverage, accuracy)
- **Terminal Mockup** — Styled SVG resembling a terminal app window with commands + output
- **Benchmark Bar Chart** — Animated growing bars comparing this project vs alternatives
- **Hero with dark/light variants** — Via `<picture>` for theme-aware rendering

See `references/visual-patterns.md` for complete, copy-paste SVG code.

Remember Rule 4: if you reference it, you MUST create it.

### 3. Feature Display — Choose the Best Format

**For 3-6 features:** Use an HTML table grid with emoji icons and short descriptions:
```html
<table>
<tr>
<td align="center" width="33%">

### ⚡ Lightning Fast
Sub-millisecond startup. No runtime overhead.

</td>
<td align="center" width="33%">

### 🔄 Live Reload
Auto-refresh on file changes. Zero config.

</td>
<td align="center" width="33%">

### 🌐 CORS Built-in
Cross-origin ready out of the box.

</td>
</tr>
</table>
```

**For 8+ detailed features:** Use blockquote cards in a 2-column HTML table. This scales better for rich feature descriptions:
```html
<table>
<tr>
<td width="50%" valign="top">

> **📸 Feature Name**
>
> Detailed description with technical specifics. Benefit-oriented — explains why this matters, not just what it does.

> **✂️ Another Feature**
>
> More detail here.

</td>
<td width="50%" valign="top">

> **🔗 Third Feature**
>
> Description.

</td>
</tr>
</table>
```

**Never use a plain bullet list for features.** That's the #1 sign of a lazy README.

### 4. Mermaid Diagrams — At Least 2 Different Types

Go beyond basic flowcharts. Pick at least TWO from: `pie`, `gantt`, `journey`, `sequenceDiagram`, `stateDiagram`, `mindmap`, `timeline`, `classDiagram`, `gitGraph`.

Choose diagram types that add genuine insight:
- **pie** → code composition, test distribution, budget breakdown
- **gantt / timeline** → roadmap (replaces boring checkbox lists)
- **journey** → user experience flow with satisfaction scores
- **sequenceDiagram** → API flows, architecture interactions
- **mindmap** → design decisions, tech stack overview
- **stateDiagram** → lifecycle, state machines, workflows

### 5. Unicode Visual Elements

For inline data that doesn't warrant a separate SVG:

```
Coverage    ███████░░░  71%
Tests       ██████████  412 passing
Memory      ████░░░░░░  24 MB
```

Use alongside tables, not instead of them. Great for coverage breakdowns, performance comparisons, and language completion percentages.

### 6. For-the-Badge Navigation CTAs

```html
<p align="center">
  <a href="#-quick-start"><img src="https://img.shields.io/badge/⚡_Quick_Start-2ea44f?style=for-the-badge" /></a>&nbsp;
  <a href="#-features"><img src="https://img.shields.io/badge/✨_Features-6366f1?style=for-the-badge" /></a>&nbsp;
  <a href="#-benchmarks"><img src="https://img.shields.io/badge/📊_Benchmarks-f59e0b?style=for-the-badge" /></a>&nbsp;
</p>
```

These replace a traditional table of contents — don't use both.

### 7. Collapsible Sections

Wrap secondary content in `<details>` blocks: installation variants, advanced config, full API docs, project structure trees, troubleshooting. The main flow should be scannable in 30 seconds.

### 8. Data Tables with Visual Indicators

```markdown
| Feature | This Project | Alt A | Alt B |
|:---|:---:|:---:|:---:|
| Feature X | ✅ | ❌ | ⚠️ |
```

---

## README Structure

Adapt based on project. Not every section applies, but visual elements are non-negotiable.

```
 1. ANIMATED HEADER BANNER (capsule-render)

 2. CENTERED HERO
    - Title with emoji
    - Tagline
    - For-the-badge navigation CTAs (these replace a TOC)
    - Metadata badges (version, CI, license, platform)

 3. VALUE PROPOSITION (2-3 sentences — why this exists)

 4. FEATURES (HTML grid or blockquote cards — never bullet list)

 5. QUICK START (numbered emoji steps 1️⃣ 2️⃣ 3️⃣ with expected output)

 6. REAL-WORLD USE CASES (creative scenarios — see Rule 3)

 7. BENCHMARKS / DATA (SVG gauges + Unicode bars + comparison table ✅❌)

 8. BEFORE vs AFTER (problem-solution table — see Rule 3)

 9. ARCHITECTURE (Mermaid diagram — sequence, graph, or mindmap)

10. INSTALLATION (ONE collapsible section, multiple methods inside)

11. USAGE EXAMPLES (realistic code with expected output)

12. COMPETITOR COMPARISON (honest feature matrix — see Rule 3)

13. API / MODULE REFERENCE (collapsible)

14. ROADMAP (Mermaid gantt or timeline — not checkbox list)

15. CONTRIBUTING (welcoming tone)

16. LICENSE

17. ANIMATED FOOTER BANNER (capsule-render)
```

Sections 6, 8, and 12 are new creative additions that most READMEs miss — this is where you differentiate.

---

## Writing Style

**Professional but energetic.** Technically precise, zero fluff. Short punchy sentences — 2-3 per paragraph max.

**Lead with value, not mechanics.** "Why" before "How."

**Benefit-oriented features.** Not "Supports WebSocket connections" but "Real-time updates via WebSockets — no polling, no delays."

**Emojis as visual anchors** in section headers and feature icons — not in prose.

---

## Self-Check Before Delivering

### Visual Checklist
- [ ] Animated gradient banner at top (capsule-render)
- [ ] At least one custom .svg file — AND the file actually exists on disk
- [ ] Features use HTML grid or blockquote cards — NOT bullet list
- [ ] 2+ different Mermaid diagram types (not just flowchart)
- [ ] Unicode visual elements (progress bars, star ratings, or block comparisons)
- [ ] For-the-badge navigation CTAs linked to sections
- [ ] 2+ collapsible `<details>` sections
- [ ] Footer banner (capsule-render)

### Content Integrity Checklist
- [ ] Zero content loss from original (if improving existing README)
- [ ] No information appears more than once (check stats, installation, badges)
- [ ] All numbers verified (LOC totals, test counts, metrics add up)
- [ ] All referenced files (SVGs, images) actually exist and are saved to disk
- [ ] Original visual patterns preserved where they were already strong

### Creative Value Checklist
- [ ] At least 2 new creative sections added (use cases, before/after, competitor comparison, user journey, troubleshooting flowchart)
- [ ] Comparison table with ✅ ❌ against alternatives (if alternatives exist)
- [ ] Real-world scenarios that help users imagine using the project

If any are missing, go back and fix before delivering.

## Lessons Learned (from real user feedback)

These override any conflicting guidance above. They represent hard-won insights from iterating with a demanding user.

### L1: Transform, Don't Reformat

The #1 failure mode is reading existing content and putting it back in a slightly different container (blockquote → table, table → blockquote). That's not creative — it's lateral.

**Transform means:** The data is the same, but the reader experiences it completely differently. A before/after comparison table becomes an animated SVG that shows the transformation visually. A feature list becomes a row of cards or a short animated diagram that demonstrates each one.

If someone could diff the old and new sections and say "you just moved stuff around" — you failed.

### L2: Hook Sections Must Be Under 15 Seconds

Problem/hook/hero sections: **one bold sentence + one visual**. That's it above the fold. Details go in a `<details>` block below.

- ❌ A paragraph explaining the problem + a before/after table = 60+ seconds to read
- ✅ One sentence + animated SVG showing the problem = 5 seconds to absorb

The collapsible contains the detailed comparison for people who want it. The visible surface is scannable in seconds.

### L3: Animated SVGs Over Static Text

For any section that tells a story (problem, how-it-works, comparison), create an **animated SVG** instead of a text table or static diagram. GitHub renders SVG animations in `<img>` tags — CSS `@keyframes` and SMIL `<animate>` both work.

Examples:
- Problem section → a cluttered desktop of files that tidies itself into a single shared link (the solution)
- Coverage section → animated gauge arcs that fill to their percentages
- Install section → terminal with lines appearing sequentially

An animated SVG is worth 50 lines of markdown.

### L4: Every Section Needs an Interactive Element

If a section has no `<details>` block, no anchor link, no clickable badge — it's passive. Passive sections get skimmed.

**Minimum interactivity per section:** at least one `<details>` with a compelling summary line that makes people WANT to click it.

The summary line is crucial: `<summary><b>What exactly changes?</b> — <i>5 things the built-in screenshot tool can't</i></summary>` beats `<summary>Details</summary>`.

### L5: Never Touch Brand Assets

Never overwrite, redesign, or modify existing SVG logos, hero images, comparison charts, or any visual identity file. These are the product's brand. Reference them as-is.

If new SVGs are needed, create NEW files alongside the existing ones. If existing SVGs need updating, describe the proposed changes and get explicit approval before writing.

### L6: SVG Must Be Valid XML — No Emoji, No HTML Entities

GitHub renders SVGs inside `<img>` tags, which means:
- **No emoji characters** (📸✂️🔗⚡✅) — they won't render. Use XML entities (`&#9733;` for ★, `&#8594;` for →, `&#183;` for ·) or plain text labels instead.
- **No `&nbsp;`** — use `&#160;` or regular spaces. SVG is XML, not HTML.
- **Always validate** with `xmllint --noout file.svg` before committing.
- **Test rendering** — the SVG must render when opened directly in a browser. If it doesn't render locally, it won't render on GitHub.

### L7: SVGs Must Not Look Like App UI

Animated SVGs that resemble an app interface (toolbars, panels, settings windows) set false expectations about what the product looks like. Users install the app expecting that UI and feel misled.

Use **abstract infographics** instead: conceptual icons, data visualizations, flow diagrams, signal paths. These communicate *capabilities* without implying *appearance*.

- Speed → a gauge or a timing bar (graph, not a progress control)
- Sync → flowing dashed paths between dots (diagram, not a panel)
- Capture → a viewfinder outline (icon, not a toolbar)
- Privacy → a lock with a short glow (icon, not a settings screen)

### L8: Collapsible Content Must Be Instant to Scan

When someone clicks a `<details>` block, they want a 3-second payoff — not a wall of text. Collapsible content should be MORE scannable than the main content, not less.

- ❌ 5 blockquote paragraphs with technical jargon (60+ seconds)
- ✅ A compact table: icon | before | after — 5 rows, ~5 words each (3 seconds)

Rule: if the collapsed content takes longer to read than the summary promised, it's broken.

### L9: Verify Product Facts Before Committing

Never assume product details (pricing, licensing model, open-source status). If the user says "$12" — use $12. If the product is proprietary — don't mark it "open source." Wrong facts in a README destroy credibility instantly.

### L10: Work Section by Section

For complex README rewrites, work one section at a time with the user. Get feedback on each section before moving to the next. A full 2000-line README rewrite that misses the mark wastes everyone's time.

## Output

Always produce:
1. A complete `README.md` file saved to disk
2. All `.svg` files referenced by the README — saved alongside it
3. Brief changelog (when improving an existing README) listing what was added, changed, and preserved
