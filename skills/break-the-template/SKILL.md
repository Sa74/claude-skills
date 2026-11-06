---
name: break-the-template
description: >
  A method for turning template-shaped deliverables (articles, web pages,
  decks, docs, READMEs, dashboards, portfolio pieces) into experiences people
  actually want to consume. USE THIS SKILL whenever the user asks for content
  to be "fun", "visually engaging", "creative", "out of the box", "memorable",
  "not boring", "less dry", or "easier to consume"; whenever they push back
  with "this still reads the same", "too much text", or "you're stuck in a
  template"; whenever they ask to "reimagine", "redesign", or "rethink" how
  something is presented; and whenever you're about to produce a
  heading-paragraph-figure document for content that deserves better. Even if
  the user only hints at wanting more visual storytelling or shorter reading
  time, use this skill before writing a single section.
---

# Break the Template

You were asked to make something engaging, and you are about to produce a
document: headings, paragraphs, a figure with a caption, repeat. This skill
exists because that instinct is strong, invisible to you, and almost always
wrong for this kind of request. It was distilled from a real session where it
took an author four rejected attempts to escape their own template — the
lessons below are what finally worked.

## The trap you are in (read this first)

Three biases produce template-shaped work, and none of them feel like biases
from the inside:

1. **Inherited structure feels immovable.** The existing page layout, the
   essay form, the slide deck grid — you treat these as the laws of physics
   when they are just the previous decision. Nobody ordered a prose column.
2. **Decoration feels like reimagination.** Adding animation to a diagram,
   theming sections, renaming chapters "tracks" — these change the skin while
   the reader's experience (scroll, read paragraph, look at box, repeat)
   stays identical. If the consumption loop is unchanged, you changed nothing.
3. **You optimize against the failure you can measure.** Builds break loudly;
   blandness is silent. So you converge toward safe, valid, forgettable.
   Treat "a reader would not screenshot any part of this" as a build failure.

The tell that you're trapped: your plan describes *sections* before it
describes *what the audience does*.

## The method

### 1. Name the template you're about to follow

Say it explicitly: "the default here is a scrolling article with section
headings" / "the default is a 12-slide deck of bullet points". You cannot
break a structure you haven't admitted you're using. Then write the
**kill-list**: the elements you are deleting, not restyling (e.g. "no
paragraphs over 2 sentences", "no figure captions", "no section headings").
If the kill-list is empty, you are decorating.

Beware the **false escapes** — structures that feel creative because they
animate, but are templates all the same: scrollytelling chapters,
hero-sections with count-up stats, card grids, vertical timelines, tabbed
panels. In benchmarked head-to-heads these are exactly what capable models
produce *without* this skill. If your "new" structure appears on a
component-library homepage, it's a template with confidence.

### 2. Find the medium's native superpower

Ask: what can THIS medium do that the template ignores? A browser can make
sound, respond to clicks, know where you've scrolled, run a simulation. A
deck can control pacing and reveal. A README renders inside a developer's
moment of evaluation. The strongest experiences let the audience **do or
feel the subject**, not read about it: a piece about typography should let
you set the type; a post about latency should make you wait and feel it; a
doc about a maze-solver should let you race it.

### 3. Find the conceit — one governing metaphor, fully committed

A conceit is a world the content lives in, drawn FROM the subject itself:
a making-of told as a workshop you walk through; a migration story told as a
moving-day; an API doc told as a restaurant menu. Two rules make a conceit
work:

- **It must come from the subject.** A photo app's story belongs in a
  darkroom; a random "space theme" is a gimmick. If the metaphor
  could be stapled onto any topic, it's wallpaper, not a conceit.
- **Total commitment.** Translate EVERY element into the conceit's
  vocabulary — headings become signage, the org chart becomes a parody of
  the product's own UI, trade secrets become a safe with torn-off cards,
  the FAQ becomes the complaints box. The moment you fall back to a plain
  section, the spell breaks. Half a conceit reads worse than none.

### 4. Decide what the audience does, and budget their time

Write one sentence: "The reader spends N minutes doing X." (e.g. "3 minutes
walking through a room, pressing two things.") Then enforce a copy budget —
the sticky-note rule: **no unit of text longer than two sentences**, total
words counted and capped. Long-form prose is what the template wants; resist
it everywhere. Information you'd have written as paragraphs becomes labels,
speech bubbles, captions on artifacts, marginalia.

**Compression must cost zero facts.** Before designing anything, write a
fact manifest: every number, name, date, and claim in the source material,
ranked by what the audience came for (a recruiter reads an About page for
seniority and proof; a team reads a quarter recap for the numbers and the
honest miss — those facts are load-bearing and uncuttable). After building,
walk the manifest and confirm each fact survived — a unit change
(1.9s → 1900ms) is fine; an omission is a defect, however small it seems.

And the mirror rule: **invent nothing.** When a piece turns playful, the
strong temptation is to fabricate charming specifics — a fake uptime
counter reading "2,191 days", a made-up "27 layers", a derived statistic
whose math nobody checked. These read as facts and poison trust in all the
real ones. Make jokes with form (a blinking sign, a sleeping robot, a torn
card), never with data; if a gag seems to need a number that isn't in the
source, the gag is wrong, not the source. Creativity spends on form; the
facts are not its budget.

### 5. Pitch before you build

Generate **2–3 genuinely distinct concepts**. Distinct means different
*consumption models* — explore vs. scroll vs. play — not three skins of the
same page. For each: the conceit, what the audience does, what gets deleted,
one vivid detail that proves you've imagined it (the detail sells the pitch:
"the office plant has been dead since week one"). Recommend one. If a human is
present, let them pick or merge; if not, choose, and ship a short note with
the deliverable naming the concept and the alternatives you rejected.

### 6. Build with craft rules

- **Motion must teach or be physical.** An animation earns its place by
  demonstrating a fact (a progress bar that really waits the full delay) or by
  behaving like a real object (a sticky note lifting). Looping decoration is
  noise. Same test for interactivity: pressing the button must cause the
  real phenomenon, not a simulation of it, wherever the medium allows.
- **Constraints become features.** Can't reveal trade secrets? Redact them
  theatrically — a safe, censor bars, torn cards — and say so. Limits played
  openly read as confidence; limits hidden read as gaps.
- **Stay inside the design system.** Use the host project's tokens, fonts,
  and themes. Breaking the template is structural rebellion, not visual
  vandalism — the wildest concept should still look native in light and
  dark mode.
- **Floors that are not optional:** respect `prefers-reduced-motion`
  (freeze everything), make sound strictly opt-in, keep semantic structure
  and alt text for what screen readers need.
- **Verify with your eyes.** Render every visual and look at it before
  calling it done. Layout collisions, clipped text, and wrong content
  survive in code that compiles.

## When the feedback is "it's still the same"

Do not polish harder at the same level. Escalate one rung:

```
styling  →  structure  →  consumption model  →  medium
(colors,    (order,        (what the reader      (page makes sound,
 fonts,      sections,      DOES: explore,        becomes a game,
 motion)     density)       play, walk, press)    a comic, a room)
```

Most "make it engaging" requests are solved at rung 3 or 4. If you've
been asked twice and you're still at rung 1–2, jump straight to 4.

## Self-tests before you ship

- **The manifest test:** take the fact manifest and find each entry in the
  final piece, one by one. Anything missing goes back in before anything
  else gets polished. Then scan the piece for specifics (numbers, dates,
  named figures) that are NOT in the manifest — each one is either deleted
  or clearly framed as fiction.

- **The textbook test:** could this visual appear unchanged in a textbook?
  Then it explains, but it doesn't delight — push further.
- **The topic-swap test:** swap in a different subject; does the structure
  survive intact? Then it's a template wearing a costume.
- **The ten-second test:** what does the audience do in the first ten
  seconds? If the honest answer is "begin reading", reconsider the opening.
- **The retelling test:** can someone describe the piece in one sentence
  that makes a stranger smile? ("Her About page is a recipe card, and you
  can tear a tab off the bottom.")

## Worked example (compressed)

A making-of page for a desktop app went through this arc: **v1** — essay
with diagrams (template). **v2** — sections renamed, diagrams animated
(decoration; rejected). **v3** — a live demo of the app's central trick,
bolted onto the same essay (right rung, wrong structure; rejected). **v4** —
the page became one continuous illustrated room the reader walks through,
every fact an object they can look at or press, about 500 words in total.
Accepted. The difference between v2 and v4 was not effort — it was rungs.
