# What does the Core lack for JSON's 15 Options?

Research for issue [#80](https://github.com/a1exk-dev/codestyle-home/issues/80) (map [#77](https://github.com/a1exk-dev/codestyle-home/issues/77)). Each gap here may become a Core fix ticket of that map.

Question: what does the Core lack, today on `develop`, to format JSON's 15 Options and to run JSON's Behaviour Records?

Date of research: 2026-11-19. Sources:

- The Core, `a1exk-dev/codestyle.nvim` `develop` at `130f1ff`: `lua/codestyle/types.lua`, `block.lua`, `wrap.lua`, `alignment.lua`, `spacing.lua`, `spacing_builder.lua`, `indent.lua`, `general.lua`, `markers.lua`, `text.lua`, `format_run.lua`, `engine/`, `testing/`, `tests/test_general.lua`, Core ADR-0002, ADR-0007 and ADR-0018.
- The Research Corpus in `~/Projects/phpstorm-editorconfig/` (PhpStorm 2026.2.3): `docs/languages/json.md`, `data/behavior/json/*.json` and `tests/formatter/json/`.
- IntelliJ Community `master` at `6f97bcb`: `json/src/com/intellij/json/formatter/JsonBlock.java`, `JsonFormattingBuilderModel.java`, `JsonTrailingCommaRemover.java`, and `platform/code-style-api/src/com/intellij/formatting/SpacingBuilder.java`.
- A probe of the Tree-sitter `json` parser in Neovim on this machine. The `json5` and `jsonc` parsers are not installed here.

Terms follow the Core's `GLOSSARY.md`. This note gives facts, and at most one line of fix direction per gap.

## Answer

The JSON records hold 1562 formatting checks (`results × inputs` over the 22 record files; the 4 records with no inputs or with `untestable-via-cli` give none). The Core lacks eight things. Gaps 1, 2, 4 and 5 are sure from the code. The others are sure about the behaviour, but less sure about where the fix belongs.

| # | Gap | Options and records that need it | Core files | How sure |
| --- | --- | --- | --- | --- |
| 1 | No parent-dependent line feed Spacing | `object_wrapping`, `array_wrapping`, `spaces_within_braces`, `spaces_within_brackets`, `keep_line_breaks`, `property_alignment`, `max_line_length`, `wrap_long_lines` | `spacing.lua`, `spacing_builder.lua`, `engine/layout.lua` | high |
| 2 | A chop-down Wrap chops only when a line passes the margin | `object_wrapping` and `array_wrapping` = `on_every_item` | `engine/layout.lua` | high (behaviour), medium (IntelliJ's mechanism) |
| 3 | No `always` Wrap type, and no wrap in a Gap without Spacing | `object_wrapping` and `array_wrapping` = `split_into_lines` (the default) | `wrap.lua`, `engine/layout.lua` | medium (a plugin can partly emulate it) |
| 4 | Blank lines in a Gap get no indent, and keep their stray blanks | `keep_indents_on_empty_lines` (with `keep_blank_lines_in_code` ≥ 1) | `engine/layout.lua`, `text.lua` | high |
| 5 | The inner lines of a multi-line leaf do not move with it | `indent_size`, `indent_style`, `tab_width` (block comments in `comments.json`) | `engine/layout.lua` | high |
| 6 | A kept trailing comma makes its array or object read-only | `keep_trailing_comma` = `true`, and every record with `trailing.json`, `trailing.json5` or `json5_misc.json5` | `engine/init.lua` | medium |
| 7 | Neither a plugin nor `codestyle.testing` knows the input's dialect (`.json` or `.json5`) | `keep_trailing_comma`, and the 146 checks on `.json5` inputs | `types.lua`, `format_run.lua`, `testing/init.lua`, `testing/checks.lua` | medium-high |
| 8 | Nothing does "Ensure right margin is not exceeded" | `wrap_long_lines` | none yet (`format_run.lua` or a plugin `after` step) | medium (where it belongs) |

## The gaps

### 1. No parent-dependent line feed Spacing

PhpStorm's JSON Spacing puts the space inside brackets and braces with `withinPair(L_BRACKET, R_BRACKET).spaceIf(SPACE_WITHIN_BRACKETS, true)`, and the same for `L_CURLY`/`R_CURLY` (`JsonFormattingBuilderModel.createSpacingBuilder`). In `SpacingBuilder`, `spaceIf(option, true)` is `parentDependentLFSpacing`, which makes `Spacing.createDependentLFSpacing`: "If … parent block spans multiple lines, insert single line break". This is why `[` and `{` get a line break after them, and `]` and `}` one before them, whenever the array or object ends up on several lines. The records show it under every wrap value. For example, with `object_wrapping = off` on `align.json`:

```
  "dd": {
    "x": 1, "longer_key": 2, "k": {
      "deep": 1, "deeper_key": [
        1
      ]
    }
  },
```

And with `array_wrapping = normal`, margin 40, on `r2_top_array.json`, `[1, "two", null, true, 4.5e10, {"k": "v"}, [5]]` becomes `[` / `1, "two", null, true, 4.5e10,` / `{"k": "v"}, [5]` / `]`.

The Core has no such Spacing. `codestyle.Spacing` holds only `min_spaces`, `max_spaces`, `min_line_feeds`, `keep_line_breaks` and `keep_blank_lines` (`spacing.lua`), and `spacing_builder.lua:17` says "Not ported: `parentDependentLFSpacing`". The layout pass decides each Gap once, from its Spacing and Wraps (`engine/layout.lua`, `line_feeds_of`). Nothing makes a Gap depend on whether a Block's range is on one line in the output.

Two odd results probably come from how IntelliJ orders this rule with indents and Alignment. A port may not match them at first, so they may need entries in `expected_failures`. How sure: low.

- With `object_wrapping = off`, `align_oneline.json` gives `{` / `  "a": 1, "bbb": "text", "cccccc": [` / `  1,` / `  2` / `], …`. The array's items get indent 2, and `]` gets column 0. The Core counts indent from the line where the parent starts (`engine/layout.lua:255`), so it would give 4 and 2. In `align.json` (`"dd"` above), the Core rule gives PhpStorm's result.
- With `property_alignment = align_on_value` on the same base, the break after `{` is gone: `{"a":    1, "bbb": "text", "cccccc": [`.

Fix direction: an optional dependent range on `codestyle.Spacing`, `spacing_builder` support for `spaces(count, true)`, and a layout pass that settles the line feed after the range's line count is known.

### 2. A chop-down Wrap chops only when a line passes the margin

With "Chop down if long", PhpStorm also splits an array or object whose items are on more than one line, because an item was broken by its own Wrap. With `object_wrapping = on_every_item` on `align.json`, `"dd": {"x": 1, "longer_key": 2, "k": {…, "deeper_key": [1]}}` is split into one property per line. The line is short, but the `deeper_key` array is "Wrap always". For `array_wrapping = on_every_item`, the corpus says an array is chopped "when it does not fit the margin … or when an element is an object", and objects are "Wrap always" on that base. `JsonBlock` gives each object and array one Wrap that all its items share (`Wrap.createWrap(OBJECT_WRAPPING, true)`). So the chop is the platform's handling of a chop-down Wrap whose group has a broken member. I did not trace that part of the platform source.

The Core marks a chop-down group as chopped only in the margin check: `chopped[wrap] = true` at `engine/layout.lua:299`, reached only when `col > right_margin` on a one-line leaf.

Fix direction: also chop a group when any line break (from a Wrap or a Spacing) lands inside the range of its members.

### 3. No `always` Wrap type, and no wrap in a Gap without Spacing

The default of both wrap Options is "Wrap always" (`split_into_lines`). `JsonBlock` gives every item of an object or array the container's Wrap, also a comment item. That is why `"a": 1, // one` becomes `"a": 1,` / `// one`. `codestyle.WrapType` is only `'normal' | 'chop_down'` (`wrap.lua`). Also, the layout applies Wraps only in Gaps that have a Spacing: `if leaf.fixed_gap or not spacing then return old end` (`engine/layout.lua:196`). PhpStorm wraps a Gap even when no Spacing rule covers it. The Gap after a comment is such a Gap: its blank lines are not limited, `blanks_comments.json`.

A plugin can stand in for "Wrap always" with Spacing rules that have `min_line_feeds = 1` before each item, and no blank-line limit after comments. But that line break does not count as a wrap for gap 2. So this is a gap only when the fix for gap 2 is tied to Wraps. How sure: medium.

Fix direction: add `always` to `codestyle.WrapType`, and let Wraps act in Gaps that have no Spacing.

### 4. Blank lines in a Gap get no indent, and keep their stray blanks

With "Keep indents on empty lines" on and `keep_blank_lines_in_code = 2`, PhpStorm writes the indent of the next line on each kept blank line. `empty_lines.json` gives `{` / `  "a": 1,` / `  ` / `  "b": {` / `    ` / `    "c": [` … (record `ij_json_keep_indents_on_empty_lines`, 12 checks, two inputs). With the Option off, the same blank lines are empty, also when the input had `  `, `\t` or `   ` on them (the base output `keep_blank_lines_in_code = 2`).

The Core never writes blanks on a blank line. When a Gap's line feeds change, it writes `('\n'):rep(place.line_feeds)` and then the indent of the leaf's own line only (`engine/layout.lua:352`). When they don't change, it leaves the blank lines as they are. The trailing-space step `text.trim_changed` keeps a blank-only line when the Option is on, and trims only lines that changed (`text.lua:129`). So a stray `\t` on an unchanged blank line survives with the Option off. The Core's only test of the Option, `tests/test_general.lua` "the indent that "Keep indents on empty lines" puts on a blank line stays", uses a fixture `before` step that leaves `  ` behind. No Core code writes that indent. Core ADR-0018 says the trailing-space step keeps "the indent that 'Keep indents on empty lines' puts on a blank line", but nothing puts it there yet.

Fix direction: the layout writes each blank line of a Gap it touches as either the next line's indent or empty, by the spec's `keep_indents_on_empty_lines` key.

### 5. The inner lines of a multi-line leaf do not move with it

`comments.json` has a block comment over two lines: `/* block` / `   comment */`, starting at column 0. On the Default base, PhpStorm indents the first line by 2 and moves the second line by the same amount (`     comment */`). With `indent_size = 8` the second line moves by 8 (`           comment */`). With `indent_style = tab` it becomes `<TAB> comment */`, written with tabs like an indent (records `indent_size`, `indent_style`, `tab_width`). The corpus says that tabs apply "to continuation lines of block comments".

The Core places a multi-line leaf by its first line only. After the leaf, the layout reads the column of its last line from the old text (`engine/layout.lua:285`, the `else` branch), and the edits touch only Gaps. Core ADR-0002 says "the formatter changes only the gaps between blocks". A fix changes text inside a leaf, so _it goes against Core ADR-0002 as written, and is worth reopening, because PhpStorm's output does it_.

Fix direction: shift each inner line of a multi-line leaf by the change of its first line's column, and write the leading whitespace with the leaf's tab Options.

### 6. A kept trailing comma makes its array or object read-only

`JsonTrailingCommaRemover` is a `PreFormatProcessor`. When `KEEP_TRAILING_COMMA` is off, it deletes each comma before a `]` or `}`, also across comments and when the parser marked the comma as an error. A Language Plugin can do the same in a `before` step, because the Core parses the text again after each step (`format_run.lua`). That part works.

When the comma stays, the Tree-sitter `json` parser does not accept it. The probe of `{"a": [1, 2, 3,], "b": {"x": 1,}, …}` gives `(array (number) (number) (number) (MISSING number))` and an `(ERROR)` in the object. The Core keeps the lines of an `ERROR` node, and of the whole parent of a `MISSING` node, as written (`engine/init.lua:58` `broken_parts`, Core ADR-0002). So with `keep_trailing_comma = true`, and on every `.json5` input (where PhpStorm never removes the comma), the arrays and objects that have a trailing comma are not formatted. The records expect `[1, 2, 3,]` to be split under "Wrap always". This touches the 5 checks of `ij_json_keep_trailing_comma` and up to 224 checks whose input is `trailing.json`, `trailing.json5` or `json5_misc.json5`.

One way around it in the plugin is the `json5` parser, which should accept trailing commas, unquoted keys and comments. It is not installed on this machine, so this is not checked. That way needs gap 7.

Fix direction: either the plugin uses `json5` for every JSON file (then gap 7), or the Core lets a plugin mark some `ERROR`/`MISSING` nodes as harmless. The second goes against Core ADR-0002.

### 7. Neither a plugin nor `codestyle.testing` knows the input's dialect

PhpStorm removes trailing commas only in plain JSON: `JsonTrailingCommaRemover` returns early when the file's language is not `JsonLanguage.INSTANCE`, and the corpus confirms that `.json5` files keep their commas. A Core `codestyle.FormatContext` has `language`, `parser`, `root`, `source`, `values`, `range`, `uses` and `fragment`, but no filetype or path (`types.lua`; `context()` in `format_run.lua`). So a plugin can tell the two dialects apart only by `ctx.parser`, and only while the two filetypes map to different parsers.

`codestyle.testing` picks one parser per language, the first installed parser of `parsers.default` (`testing/init.lua:77`). It formats every record input with it (`parser = deps.parser`, `testing/checks.lua:169`), whatever the file's extension. The JSON records have two `.json5` inputs, `trailing.json5` and `json5_misc.json5` (unquoted keys, single quotes, `0xFF`, `Infinity`), in 146 checks. The `json` parser turns `json5_misc.json5` into one `ERROR` node (probe).

Fix direction: `codestyle.testing` picks the parser by the input's filetype through `spec.parsers`, and `FormatContext` gets an optional `filetype`. Both are additive under Core ADR-0007.

### 8. Nothing does "Ensure right margin is not exceeded"

`ij_json_wrap_long_lines` (`common:WRAP_LONG_LINES`, 48 checks) hard-wraps the first overlong stretch of a file after formatting, at item boundaries. It has odd details: continuation lines get indent 2, a line after a colon starts at column 0, and later overlong lines are left as they are. `JsonBlock` and `JsonFormattingBuilderModel` never read `WRAP_LONG_LINES`, so PhpStorm does this outside the JSON Blocks, after the formatter. I did not trace the platform code. Nothing in the Core reads such an Option (searched for `wrap_long`). A Language Plugin can do it in an `after` step, which gets the values and the text. `WRAP_LONG_LINES` is a common field of every language, so the Core might own it as a file-wide rule, as Core ADR-0018 does for trailing spaces. That is a design decision for the map. How sure: medium.

## What already works

- **Spaces** (`space_before_colon`, `space_after_colon`, `space_before_comma`, `space_after_comma`): `spacing_builder` `before`/`after` with `spacing(n, n, 0, false, 0)` copies PhpStorm's rules. `keep_line_breaks = false` joins `"key_d"` / `: "late colon"` (`continuation.json`).
- **`spaces_within_braces` / `spaces_within_brackets`**: `within_pair(...).space_if(...)` gives the space half, including `{ }` and `[ ]`. The line feed half is gap 1.
- **`keep_blank_lines_in_code` and `keep_line_breaks`**: `codestyle.Spacing.keep_blank_lines` and `keep_line_breaks`, and the builder's `keep_line_breaks`/`keep_blank_lines` options, which take functions of the values. The unlimited blank lines after comments need only that no rule covers those Gaps, and gap 3 for the Wrap.
- **`object_wrapping` / `array_wrapping` = `normal`**: the `normal` Wrap with `wrap_first = true` (as `Wrap.createWrap(…, true)`) breaks before the item that passes the margin. Together with gap 1 it gives the filled lines of `long_array.json`.
- **`property_alignment`**: `alignment.new({ backward_shift = true })`, as `Alignment.createAlignment(true)`, on the colon (`align_on_colon`), or on the value or the value's opening bracket (`align_on_value`, as WEB-13587 in `JsonBlock`). The Core aligns only the first member of a group on each line (`engine/layout.lua:268`). That matches the Do-not-wrap records: in a one-line object only the first property is padded, to the column of `], "dd": {` on a later line.
- **`indent_size`, `indent_style`, `tab_width`**: `indent_options` gives `size`, `use_tab` and `tab_size`. The Core writes whole tab stops as tabs and the rest as spaces, which matches "level 3 a tab plus two spaces" at Indent 2 and Tab size 4. Continuation indent and Smart tabs have no visible effect in JSON and no checks.
- **`max_line_length`**: an integer Option with `inherit = 'hard_wrap_at'`. An absent or `-1` `RIGHT_MARGIN` leaves the default, so the margin is 120.
- **`general`** (Core ADR-0018): `on_marker_in_region = true` exists for JSON's on-marker line. The `keep_indents_on_empty_lines` spec key exists, but see gap 4.
- **The spec and scheme shape**: `choice` Options with scheme `values` for `custom:ARRAY_WRAPPING`/`OBJECT_WRAPPING` (`0`, `1`, `2`, `5`) and `custom:PROPERTY_ALIGNMENT` (`0`, `1`, `2`). A Group with its own Option holds "Objects" › "Align". Filetypes and PhpStorm's globs (`.babelrc`, `composer.lock`, …) are handled by `match_globs` (Core ADR-0015).
- **`codestyle.testing`** reads every JSON record. Every `base_settings` spelling translates (`common:`, `common:INDENT.`, `custom:`). `untestable-via-cli` records are skipped, and the `no-visible-effect` records have no inputs, so they give no checks.
- **Comments**: the Tree-sitter `json` parser has a `comment` node for `//` and `/* */` (probe).
