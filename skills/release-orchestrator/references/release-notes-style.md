# Release notes style

The notes are for the people who use the app. They are not a changelog for the
people who built it.

## Structure

- Group bullets under `### New`, `### Fixed` and `### Improved`. Leave a group
  out when it has nothing.
- Use `###` only. A second `##` inside a block ends it for any tool that
  extracts a version's notes by heading.
- The block is headed `## <tag>` when it is written to the file. Draft the
  content without the heading.

## Rules for every bullet

1. **Write for users, not engineers.** No PR titles, branch names, file paths,
   ticket ids, class names or internal jargon.
2. **Lead with what the user sees.** Fixed, Added, Faster, Improved.
3. **One line per bullet.** The problem and the fix in one sentence. A second
   sentence only when it earns its place. If a bullet needs explaining, it is
   too big: cut it down, don't add to it.
4. **Only claim what ships.** Don't quote a button label or promise a
   behaviour you haven't checked in the source. Search for it first, then
   quote it, or describe the effect without the quote.
5. **Stand on facts when challenged.** If the user questions a checkable
   claim, verify it and either hold your ground with proof or correct it.
   Don't change a claim on a guess.
6. **Leave out what users can't notice.** Refactors, test changes and tooling
   don't belong.

## Tone: `plain`

Clear, short, neutral. One fact per bullet.

- Fixed search returning nothing when the query had a typo.
- Added export to CSV from the reports screen.
- Sync finishes faster on large libraries.

## Tone: `witty`

Lightly funny, in the manner of a well-written App Store update note. The wit
lives in the phrasing and never costs accuracy: the bug and the fix must both
stay unmistakable.

Accurate, polite bullets *feel* finished. In this tone they are not. Before
presenting a draft, check each bullet:

1. **Read the most recent shipped block in the notes file.** Actually read it;
   don't go from memory. That is the register to match.
2. **Could this sentence appear unchanged in any app's changelog?** Then it
   fails. "Fixed an issue where settings were not saved" fails.
3. **Name the thing that misbehaved and give it a little character.** The bug
   is the subject of the sentence, not a passive event.
4. **Land the fix as a beat, not a clause.** A short second sentence beats a
   trailing "which has now been fixed".
5. **One joke per bullet at most.** A bullet with no wit and no character
   isn't done. Rewrite it, or decide the change is too small to list.

Getting this right on the first draft is the bar. Dry notes that wait to be
corrected waste the single approval gate.

| Dry (fails) | Witty (passes) |
|---|---|
| Fixed an issue where settings were not saved after restart. | Dark mode forgot itself every time you restarted. It remembers now. |
| Fixed a bug where the sync indicator did not stop. | The sync spinner kept spinning long after the work was done. It has learned when to leave. |
| Improved search to handle typos. | Search used to give up at the first typo. It now reads past your spelling, like a good friend. |
| Added a keyboard shortcut for export. | Export has a keyboard shortcut now, for people whose mouse is all the way over there. |

Short and dry is the failure, not the goal: trim words, keep the wit.
