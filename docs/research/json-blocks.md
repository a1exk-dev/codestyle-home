# How does PhpStorm's JSON formatter build its Blocks?

Research for issue [#79](https://github.com/a1exk-dev/codestyle-home/issues/79) (map [#77](https://github.com/a1exk-dev/codestyle-home/issues/77)). It feeds [#82](https://github.com/a1exk-dev/codestyle-home/issues/82) and the map's open question "the formatter's rules": how each JSON Option maps onto Blocks, Gaps, Wraps, Alignments and Indents.

Question: how does PhpStorm's JSON formatter build its Blocks, Spacing, Wraps, Alignments and Indents, and how does each of the 15 JSON Options act on them? Compare each finding with the Behaviour Records.

Date of research: 2026-11-19. Terms follow the Core's `GLOSSARY.md`: **Block** and **Gap**. The glossary has no entries for Wrap, Alignment, Indent or Spacing, so this note uses IntelliJ's own names for them (`Wrap`, `Alignment`, `Indent`, `Spacing`, in code font when the class is meant). That missing vocabulary is a gap for `/domain-modeling`. This note gives facts and no design.

## Sources

- **IntelliJ Community, tag `idea/262.10968.63`** (commit `8062c06`). The Research Corpus names PhpStorm build `PS-262.10968.76`. No `idea/262.10968.76` tag exists. `idea/262.10968.63` is the nearest earlier tag of the same build branch, and `pycharm/262.10968.92` the nearest later one. `git diff` between the two tags shows no change in any file cited below, so build `.76` has the same code.
- Links below are relative to `https://github.com/JetBrains/intellij-community/blob/idea/262.10968.63/`. The files:
  - JSON plugin: [`json/src/com/intellij/json/formatter/JsonBlock.java`](https://github.com/JetBrains/intellij-community/blob/idea/262.10968.63/json/src/com/intellij/json/formatter/JsonBlock.java), [`JsonFormattingBuilderModel.java`](https://github.com/JetBrains/intellij-community/blob/idea/262.10968.63/json/src/com/intellij/json/formatter/JsonFormattingBuilderModel.java), [`JsonCodeStyleSettings.java`](https://github.com/JetBrains/intellij-community/blob/idea/262.10968.63/json/src/com/intellij/json/formatter/JsonCodeStyleSettings.java), [`JsonLanguageCodeStyleSettingsProvider.java`](https://github.com/JetBrains/intellij-community/blob/idea/262.10968.63/json/src/com/intellij/json/formatter/JsonLanguageCodeStyleSettingsProvider.java), [`JsonTrailingCommaRemover.java`](https://github.com/JetBrains/intellij-community/blob/idea/262.10968.63/json/src/com/intellij/json/formatter/JsonTrailingCommaRemover.java), [`JsonLineWrapPositionStrategy.java`](https://github.com/JetBrains/intellij-community/blob/idea/262.10968.63/json/src/com/intellij/json/formatter/JsonLineWrapPositionStrategy.java), [`json/src/com/intellij/json/psi/JsonPsiUtil.java`](https://github.com/JetBrains/intellij-community/blob/idea/262.10968.63/json/src/com/intellij/json/psi/JsonPsiUtil.java), [`json/src/com/intellij/json/JsonTokenSets.java`](https://github.com/JetBrains/intellij-community/blob/idea/262.10968.63/json/src/com/intellij/json/JsonTokenSets.java), [`json/src/com/intellij/json/json5/Json5Language.java`](https://github.com/JetBrains/intellij-community/blob/idea/262.10968.63/json/src/com/intellij/json/json5/Json5Language.java), [`json/resources/intellij.json.xml`](https://github.com/JetBrains/intellij-community/blob/idea/262.10968.63/json/resources/intellij.json.xml).
  - Platform: `platform/code-style-api/src/com/intellij/formatting/{Wrap,WrapType,SpacingBuilder}.java`, `platform/code-style-api/src/com/intellij/psi/codeStyle/CommonCodeStyleSettings.java`, `platform/code-style-impl/src/com/intellij/formatting/{WhiteSpace,WrapImpl,IndentInfo}.java`, `platform/code-style-impl/src/com/intellij/formatting/engine/WrapProcessor.java`, `platform/platform-impl/src/com/intellij/formatting/{LineWrappingPostFormatProcessor,LineWrappingUtil}.java`.
- **Research Corpus**: `~/Projects/phpstorm-editorconfig/docs/languages/json.md` (cited as `json.md:<line>`) and the Behaviour Records `data/behavior/json/<key>.json` (cited by key; inputs under `inputs`, Default output under `base_outputs.Default`).

## Answer

- **One Block per PSI node, no synthetic Blocks.** `JsonBlock` makes a child Block for every child AST node that is not whitespace and not empty (`JsonBlock.java:106-117`, `211-213`). So an object's Blocks are `{`, each property, each `,`, each comment, `}`; a property's Blocks are the key, `:`, any comment, and the value; an array's Blocks are `[`, each value, each `,`, each comment, `]`. Comments are Blocks like elements.
- **Wraps: one shared `Wrap` per container.** Each object makes `Wrap(OBJECT_WRAPPING, wrapFirstElement = true)`, each array `Wrap(ARRAY_WRAPPING, true)` (`JsonBlock.java:82-90`). Every child of the container that is not a brace and not a comma gets that one `Wrap`, also comments (`JsonBlock.java:128-131`). Each comma gets its own `Wrap` of type NONE (`JsonBlock.java:125-126`). Braces and all children of a property have no `Wrap`.
- **Indents: Normal for the same children, None for all else.** The children that get the container `Wrap` also get `Indent.getNormalIndent()`; braces, commas and the children of a property get `Indent.getNoneIndent()` (`JsonBlock.java:120`, `131`). The file's root Block gets a smart continuation Indent (`JsonFormattingBuilderModel.java:28-30`), which no line uses (corpus: `json.md:97`, `json.md:136`).
- **Alignments: one per object.** Each object makes one `Alignment.createAlignment(true)` (`JsonBlock.java:92`). With On colon, each property's `:` Block takes its object's Alignment (`JsonBlock.java:144-145`). With On value, a scalar value takes it (`JsonBlock.java:147-150`), and an object or array value puts it on its opening `{`/`[` instead of on the whole value (`JsonBlock.java:133-138`, "WEB-13587").
- **Spacing: six rules, first match wins** (`JsonFormattingBuilderModel.java:42-48`, `SpacingBuilder.java:359-369`):
  1. before `:` — exactly 0 or 1 space (Before ':'), **line breaks never kept** (`keepLineBreaks = false`, `keepBlankLines = 0`);
  2. after `:` — exactly 0 or 1 space (After ':'), line breaks never kept;
  3. after `[` and before `]` — 0 or 1 space (Within › Brackets), but a line break when the array spans lines (parent-dependent line-feed Spacing), Keep line breaks and Keep blank lines apply;
  4. after `{` and before `}` — the same with Within › Braces;
  5. before `,` — exactly 0 or 1 space (Before comma), line breaks never kept;
  6. after `,` — 0 or 1 space (After comma), Keep line breaks and Keep blank lines apply.

  Every other Gap has no rule (`getSpacing` returns `null`): after a comment, between a value and a following comment, between a key and a comment. A `null` Spacing leaves the Gap's line breaks and blank lines as written (`WhiteSpace.java:387-429`); only a `Wrap` or the Indent changes it.
- **Two passes outside the Blocks.** A pre-format pass deletes trailing commas in `.json` files unless Keep trailing comma is on (`JsonTrailingCommaRemover.java:26-49`). A post-format pass hard-wraps overlong lines when Ensure right margin is not exceeded is on (`LineWrappingPostFormatProcessor.java:27-45`), with JSON's own break positions (`JsonLineWrapPositionStrategy.java`).
- **Every Behaviour Record agrees with the source** where the source decides. Three observed details come from the platform engine and were not traced to a line: Chop down if long splits an array that has an object element, alignment pads only properties that start a line, and Ensure right margin wraps only the first overlong stretch of a file. See "Not traced".

## The Block tree

`JsonFormattingBuilderModel.createModel` builds the root `JsonBlock` for the file node with no Alignment, a smart continuation Indent and no Wrap, and one shared `SpacingBuilder` (`JsonFormattingBuilderModel.java:24-32`). The formatter is registered for language `JSON` (`intellij.json.xml:82`). JSON5 is a dialect: `Json5Language extends JsonLanguage` (`Json5Language.java:6-11`), so `.json5` files use the same Blocks.

`getSubBlocks()` walks the node's AST children and skips whitespace and zero-length nodes (`JsonBlock.java:106-117`, `211-213`). `makeSubBlock` then sets three things per child (`JsonBlock.java:119-154`):

| Parent Block | Child Block | Wrap | Indent | Alignment |
| --- | --- | --- | --- | --- |
| object or array (`JSON_CONTAINERS`, `JsonTokenSets.java:24`) | `,` | own `Wrap(NONE)` | None | — |
| object or array | `{`/`[` | — | None | the grandparent object's Alignment, if this container is a property value and Align = On value (`:133-138`) |
| object or array | `}`/`]` | — | None | — |
| object or array | anything else: property, value, comment | the container's shared Wrap | Normal | — |
| property | `:` | — | None | the parent object's Alignment if Align = On colon (`:144-145`) |
| property | the value, if not an object or array | — | None | the parent object's Alignment if Align = On value (`:147-150`) |
| property | key, comment, container value | — | None | — |
| file or anything else | any | — | None | — |

"Property value" means the PSI parent is a `JsonProperty` and the node is its value (`JsonPsiUtil.java:62-65`). `getChildAttributes` and `isIncomplete` (`JsonBlock.java:177-204`) only set the Indent for a new line typed with Enter; a reformat does not use them.

## Wraps and the platform

`Wrap.createWrap(int, boolean)` maps the stored integer through `WrapType.byLegacyRepresentation` (`Wrap.java:26-28`, `WrapType.java:63-66`):

| EditorConfig value | UI label | `CommonCodeStyleSettings` constant | `WrapType` | engine type (`WrapImpl.java:164-169`) |
| --- | --- | --- | --- | --- |
| `off` | Do not wrap | `DO_NOT_WRAP = 0x00` | `NONE` | `DO_NOT_WRAP` |
| `normal` | Wrap if long | `WRAP_AS_NEEDED = 0x01` | `NORMAL` | `WRAP_AS_NEEDED` |
| `on_every_item` | Chop down if long | `WRAP_ON_EVERY_ITEM = 0x04` | `CHOP_DOWN_IF_LONG` | `CHOP_IF_NEEDED` |
| `split_into_lines` | Wrap always | `WRAP_ALWAYS = 0x02` | `ALWAYS` | `WRAP_ALWAYS` |

(`CommonCodeStyleSettings.java:853-856`, `WrapType.java:15-40`.) The engine (`WrapProcessor.java:73-92`, `115-184`):

- **Wrap always**: every Block that carries the Wrap gets a line break before it (`WrapProcessor.java:84`).
- **Wrap if long**: a Block gets a line break when its line passes the right margin (`lineOver`, `WrapProcessor.java:45-48`, `85-88`). Because JSON passes `wrapFirstElement = true`, the first element can be the one that wraps (`Wrap.java:30-47`).
- **Chop down if long**: when one Block of the shared Wrap passes the margin, the engine goes back to the first Block of that Wrap, makes the Wrap active, and from then on every Block of it wraps (`WrapProcessor.java:142-151`, `173-175`, `WrapImpl.java:138-141`).
- **Do not wrap**: the Wrap never adds a line break. Existing breaks stay or go by Spacing (Keep line breaks).

The right margin is Hard wrap at (`RIGHT_MARGIN`, default `-1` = the global 120; `CommonCodeStyleSettings.java:250`, `json.md:491`).

## Each Option

The 15 Options of `json.md:11-27`, grouped by the Block they act on.

### Arrays (`ij_json_array_wrapping`) and Objects (`ij_json_object_wrapping`)

- **Field**: `JsonCodeStyleSettings.ARRAY_WRAPPING` and `OBJECT_WRAPPING`, both default `WRAP_ALWAYS` (`JsonCodeStyleSettings.java:43`, `54`).
- **Block**: the shared Wrap of each array or object (`JsonBlock.java:82-90`), carried by its elements, properties and comments (`:128-131`). Not by commas (own NONE Wrap, `:125-126`) and not by braces.
- **How**: the four types above. The brace Gaps follow from Spacing, not from the Wrap: after `{`/`[` and before `}`/`]` a line break comes when the container spans more than one line (`withinPair(...).spaceIf(..., true)` → `parentDependentLFSpacing`, `JsonFormattingBuilderModel.java:45-46`, `SpacingBuilder.java:118-139`, `183-188`). So a split container gets its braces on their own lines, and a one-line container keeps `[1, 2]`.
- **Comments**: a comment child carries the Wrap too. With Wrap always a trailing `// one` after `"a": 1,` goes to its own line, and `"x": 1 /* after x */,` becomes `"x": 1` / `/* after x */,`, because the comment wraps and then the before-`,` rule pulls the comma onto the comment's line.
- **Records**: `ij_json_array_wrapping`, `ij_json_object_wrapping` agree. Default output of `comments.json`: `"a": 1,` / `// trailing a`; `"c": [` / `1,` / `/* mid */` / `2,`; `"x": 1` / `/* after x */,` (`base_outputs.Default`). "Empty arrays are never split" (`json.md:254`): an empty container has no child that carries the Wrap. Wrap if long fills to the margin with the break first after `[` (`json.md:257`), as `wrapFirstElement` predicts. Chop down: "an array is split ... when it does not fit the margin" (`json.md:258`) matches the engine; "or when an element is an object" is in "Not traced". The odd indents with Do not wrap around a Wrap-always array (`json.md:361`, `json.md:363`) come from the Normal Indent being measured from the nearest ancestor Block that starts a line; not traced to a line here.

### Align (`ij_json_property_alignment`)

- **Field**: `JsonCodeStyleSettings.PROPERTY_ALIGNMENT`, `0` = `do_not_align`, `1` = `align_on_value`, `2` = `align_on_colon` (`JsonCodeStyleSettings.java:34`, `60-63`; EditorConfig names in `JsonLanguageCodeStyleSettingsProvider.java:122-138`).
- **Block**: one Alignment per object (`JsonBlock.java:92`), shared by its direct properties only, so each nested object aligns on its own.
  - On colon: the `:` Block of each property (`:144-145`), so padding goes into the key–colon Gap.
  - On value: the scalar value Block (`:147-150`), or the opening `{`/`[` of an object or array value (`:133-138`), so padding goes into the colon–value Gap.
- **Records**: `ij_json_property_alignment` agrees: "the colons ... in one column; every property, also those whose value is an object or array, takes part; each nested object aligns separately" (`json.md:408`); "the column is set by the longest key of that object" (`json.md:407`). "A value that was on the next line after the colon is pulled up" (`json.md:407`) is the after-`:` rule with `keepLineBreaks = false` (`JsonFormattingBuilderModel.java:44`). With Chop down an object that fits stays unpadded (`json.md:411`), and with Do not wrap only properties that start a line are padded (`json.md:405`, `json.md:413`); see "Not traced".

### Keep when reformatting › Line breaks (`ij_json_keep_line_breaks`)

- **Field**: `CommonCodeStyleSettings.KEEP_LINE_BREAKS`, default `true` (`CommonCodeStyleSettings.java:267`).
- **Block**: the Gaps after `,`, after `{`/`[` and before `}`/`]`. Those rules pass `KEEP_LINE_BREAKS` (`spaceIf` → `spaces` → `spacing(..., KEEP_LINE_BREAKS, KEEP_BLANK_LINES_IN_CODE)`, `SpacingBuilder.java:108-139`). The Gaps around `:` and before `,` pass `false` and never keep a break (`JsonFormattingBuilderModel.java:43-44`, `47`). Gaps with no rule always keep their breaks.
- **How**: with `false`, a single line break in such a Gap is removed (`WhiteSpace.java:412-419`), unless a Wrap puts it back. With Wrap always every element Gap gets a break from the Wrap anyway.
- **Records**: `ij_json_keep_line_breaks` agrees: no diff on the Default base (`json.md:301`); with Do not wrap the items join on one line, and "a line comment still ends its line" (`json.md:302`), because the Gap after a comment has no rule. "A break right after `{`/`[` and before `}`/`]` is kept when it is in the input" (`json.md:302`) matches the parent-dependent line-feed rule, which asks whether the container spans lines.

### Keep when reformatting › Trailing comma (`ij_json_keep_trailing_comma`)

- **Field**: `JsonCodeStyleSettings.KEEP_TRAILING_COMMA`, default `false` (`JsonCodeStyleSettings.java:24`).
- **Block**: none. A `PreFormatProcessor` (`intellij.json.xml:83`) runs before the Blocks are built. When the option is off, it deletes each `,` (also a `,` inside an error element) between the last element or property and the closing `]`/`}`, skipping comments and whitespace (`JsonTrailingCommaRemover.java:34-36`, `59-92`).
- **Only `.json`**: it returns at once when the file's language is not exactly `JsonLanguage.INSTANCE` (`JsonTrailingCommaRemover.java:30-32`). JSON5 is a separate `Language` object (`Json5Language.java:7`), so `.json5` files keep trailing commas whatever the option says.
- **Records**: `ij_json_keep_trailing_comma` agrees, also on JSON5: "The comma is removed in .json files only: the .json5 inputs ... keep their trailing commas on the Default base and the option has no diff on them" (`json.md:330`).

### Ensure right margin is not exceeded (`ij_json_wrap_long_lines`)

- **Field**: `CommonCodeStyleSettings.WRAP_LONG_LINES`, default `false` (`CommonCodeStyleSettings.java:958`).
- **Block**: none. `LineWrappingPostFormatProcessor` runs after the formatter, and only when `WRAP_LONG_LINES` is on (`LineWrappingPostFormatProcessor.java:27-45`). For each line past the right margin it asks the language's `LineWrapPositionStrategy` for a break offset and emulates Enter there (`LineWrappingUtil.java:92-168`).
- **JSON's break positions** (`intellij.json.xml:84`, `JsonLineWrapPositionStrategy.java:20-69`): a position inside a string, number, `true`/`false`/`null` or identifier moves to the end of that literal (`:47-56`); a position on a `:` (`:58-60`), in a comment, or just before a `,` (`:61-65`) means no wrap on that line; otherwise the default strategy picks the position. So a string is never split (`json.md:485`).
- **Records**: `ij_json_wrap_long_lines` agrees that it does nothing on the Wrap always and Wrap if long bases (`json.md:445`, `json.md:447`). Because the break is an emulated Enter, the new line gets the Enter Indent of the enclosing Block, which `getChildAttributes` gives (`JsonBlock.java:177-189`): Normal inside a container, which fits "continuation lines are indented 2" (`json.md:445`). "After a colon the next line starts at column 0" and "only the first overlong stretch of a file is wrapped" are in "Not traced".

### Keep maximum blank lines › In code (`ij_json_keep_blank_lines_in_code`)

- **Field**: `CommonCodeStyleSettings.KEEP_BLANK_LINES_IN_CODE`. The platform default is `2`, and JSON sets it to `0` (`CommonCodeStyleSettings.java:290`, `JsonLanguageCodeStyleSettingsProvider.java:117-118`).
- **Block**: the same Gaps as Keep line breaks: after `,` and inside the braces (`SpacingBuilder.java:132-138`). The Gaps around `:` and before `,` pass `0` and lose every blank line (`JsonFormattingBuilderModel.java:43-44`, `47`). Gaps with no rule keep all their blank lines.
- **How**: with `n > 0`, a Gap of more than `n + 1` line breaks is cut to `n + 1` (`WhiteSpace.java:396-400`). With `0` and Keep line breaks on, it is cut to one line break (`:401-411`). A Gap that keeps blank lines is not joined even when Keep line breaks is off, because only a single line break is removed (`:412-419`).
- **Records**: `ij_json_keep_blank_lines_in_code` agrees, including the comment case: "Blank lines after a line or block comment are not limited ... The limit is applied to blank lines before a comment and between members" (`json.md:521`). In `blanks_comments.json` the two blank lines after `// comment after blanks` and the three after `/* block */` stay at the default `0`, while the three before `// comment after blanks` (after `"a": 1,`) go: the Gap after a comment has no rule, the Gap after `,` has one.

### Keep indents on empty lines (`ij_json_keep_indents_on_empty_lines`)

- **Field**: `IndentOptions.KEEP_INDENTS_ON_EMPTY_LINES` (`CommonCodeStyleSettings.java:1047`). JSON code never reads it.
- **Block**: none of its own. When the engine writes a Gap with blank lines, it writes the Indent on each blank line too (`IndentInfo.java:65-69`).
- **Records**: `ij_json_keep_indents_on_empty_lines` agrees: visible only when blank lines survive, that is with Keep maximum blank lines ≥ 1 (`json.md:114`, `json.md:119`).

### Indent (`indent_size`)

- **Field**: `IndentOptions.INDENT_SIZE` (`CommonCodeStyleSettings.java:1038`), JSON default `2` (`JsonLanguageCodeStyleSettingsProvider.java:116`).
- **Block**: every Block with Normal Indent: the properties, values and comments of a container (`JsonBlock.java:131`). Braces and commas get None, so `}` lines up with its opening line.
- **Records**: `indent_size` agrees: "every nesting level of objects and arrays is indented by 4 columns instead of 2 (top-level array items too)" (`json.md:154`). Use tab character, Tab size, Smart tabs and Continuation indent are not among the 15, but the corpus records them (`json.md:95-242`); Continuation indent and Smart tabs have no effect because no Block gets a continuation Indent that a line uses (`json.md:97`, `json.md:136`).

### Spaces (six Options)

All six act only on the Gaps of `JsonFormattingBuilderModel.createSpacingBuilder` (`JsonFormattingBuilderModel.java:34-49`). They are shown in the UI by `JsonLanguageCodeStyleSettingsProvider.java:51-58`.

| Option | Field (default) | Gap | Rule | Line breaks in the Gap |
| --- | --- | --- | --- | --- |
| Before ':' `ij_json_space_before_colon` | `JsonCodeStyleSettings.SPACE_BEFORE_COLON` (`false`, `JsonCodeStyleSettings.java:23`) | key → `:` | `.before(COLON).spacing(n, n, 0, false, 0)` (`:43`) | always removed |
| After ':' `ij_json_space_after_colon` | `JsonCodeStyleSettings.SPACE_AFTER_COLON` (`true`, `:22`) | `:` → value | `.after(COLON).spacing(n, n, 0, false, 0)` (`:44`) | always removed |
| Brackets `ij_json_spaces_within_brackets` | `SPACE_WITHIN_BRACKETS` | `[` → first, last → `]` | `.withinPair(L_BRACKET, R_BRACKET).spaceIf(opt, true)` (`:45`) | a line break when the array spans lines |
| Braces `ij_json_spaces_within_braces` | `SPACE_WITHIN_BRACES` | `{` → first, last → `}` | `.withinPair(L_CURLY, R_CURLY).spaceIf(opt, true)` (`:46`) | a line break when the object spans lines |
| Before comma `ij_json_space_before_comma` | `SPACE_BEFORE_COMMA` | element → `,` | `.before(COMMA).spacing(n, n, 0, false, 0)` (`:47`) | always removed |
| After comma `ij_json_space_after_comma` | `SPACE_AFTER_COMMA` | `,` → next | `.after(COMMA).spaceIf(opt)` (`:48`) | by Keep line breaks and Keep blank lines |

- The within rules match any Gap whose left Block is the opening brace or whose right Block is the closing brace (`SpacingBuilder.java:281-285`), so an empty container gets `[ ]`/`{ }` when the option is on.
- A space count applies only when the Gap has no line break (`WhiteSpace.java:368-381`).
- **Records**: all six agree: `{ }` and `[ ]` for empty containers, and no padding inside split containers (`ij_json_spaces_within_braces`, `ij_json_spaces_within_brackets`); `"a" : 1` (`ij_json_space_before_colon`); `"a":1` (`ij_json_space_after_colon`, `json.md:557`); `} ,` after a closing brace (`ij_json_space_before_comma`); After comma off is visible only where commas stay inside a line (`ij_json_space_after_comma`).

## Not traced

These Behaviour Records show engine behaviour that the JSON plugin does not decide. The platform engine (`platform/code-style-impl/src/com/intellij/formatting/`) causes them, but this research did not trace them to a line:

- **Chop down if long with an object element**: the corpus says an array is chopped "when an element is an object" even if the line fits (`json.md:258`). Objects are Wrap always on that base, so the object's own line breaks seem to make the array's chop-down Wrap active. The candidates are the parent-Wrap links (`WrapImpl.registerParent`, `InitialInfoBuilder.java:126`) and `WrapProcessor.java:153-158`.
- **Alignment of a property that does not start a line**: with Do not wrap or Wrap if long, a property that shares a line is not padded (`json.md:405`, `json.md:413`, `json.md:415`). The source gives every property the Alignment (`JsonBlock.java:144-150`), so the engine must skip Alignments of Blocks that are not first on their line.
- **Ensure right margin wraps only the first overlong stretch**: the corpus saw one wrapped stretch per file (`json.md:442`, `json.md:445`). `LineWrappingUtil.doWrapLongLinesIfNecessary` walks every line in the range (`LineWrappingUtil.java:118-167`), but returns early once the preferred wrap position passes the end of the range (`:134-136`). Whether that range is stale after the first Enter was not checked. The same pass breaks after a `:` and starts the next line at column 0 (`json.md:445`), although a position on the `:` itself is skipped (`JsonLineWrapPositionStrategy.java:58-60`); `getChildAttributes` gives a property `ChildAttributes(null, null)` (`JsonBlock.java:187-188`), and how the Enter handler turns that into column 0 was not checked.
- **Indent of elements after a container that starts mid-line** (`json.md:361`): the platform measures a Normal Indent from the nearest ancestor Block that starts a line.

Each of these is already in a Behaviour Record, so a test against the records will catch a formatter that differs.
