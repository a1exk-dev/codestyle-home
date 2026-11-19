# Which nvim-treesitter parsers parse PhpStorm's JSON inputs?

Research for issue [#78](https://github.com/a1exk-dev/codestyle-home/issues/78) (map [#77](https://github.com/a1exk-dev/codestyle-home/issues/77)). It feeds the JSON spec's `filetypes` and `parsers` table (Core ADR-0015) and the node and field names that the formatter's rules name (Core ADR-0007).

Question: which of the parsers `json`, `jsonc` and `json5`, on nvim-treesitter `master` (the commit that the template's `test/deps.lua` pins) and on `main`, parse the 33 inputs of `tests/formatter/json/` in the Research Corpus with no `ERROR` or `MISSING` node? Which node types and field names does each one give? Which filetypes does Neovim give these files, and which globs does PhpStorm give JSON?

Date of research: 2026-11-19. Sources: nvim-treesitter at the pinned `cf12346` (tip of `master`) and `main` at `37e52c7`; tree-sitter-json, tree-sitter-json5 and tree-sitter-jsonc at the revisions below; the Neovim `v0.12.6` runtime; IntelliJ Community `master` (`6f97bcb`); `data/catalog.json`, `docs/languages/json.md` and `tests/formatter/json/` in `~/Projects/phpstorm-editorconfig/`. Terms follow the Core's `GLOSSARY.md`. This note gives facts and no design.

## Answer

- **`json5` is the only parser that parses all 33 inputs, and only on `main`.** On `master`, `json5` fails one input: its grammar at that revision allows only an object or an array at the top, so `r2_scalars.json` (`"just a string"`) gives `(file (ERROR (string)))`.
- **`json` and `jsonc` parse the same 30 inputs and fail the same 3:** `trailing.json` (trailing commas), `trailing.json5` and `json5_misc.json5` (trailing commas, unquoted and single-quoted keys, hex, `Infinity`). Both parse `//` and `/* */` comments. `json` on `master` and on `main` gives the same results.
- **Neither JSON parser accepts a trailing comma.** `trailing.json` is a `.json` file, and Neovim gives it the filetype `json`. PhpStorm formats it, and it is an input of the Trailing comma Option (`ij_json_keep_trailing_comma`) and of the wrapping Options. With `json` or `jsonc` its tree has `MISSING number` and `ERROR` nodes.
- **`jsonc` is obsolete.** nvim-treesitter `main` removed it on 2025-12-06 (`d235075`, "remove gitlab-hosted blueprint, fusion, jsonc"), and maps the filetype `jsonc` to the `json` parser. Its upstream repo says, since 2026-01-28 (`f7890ba`): "tree-sitter-json now supports both JSON and JSONC. This package is obsolete." Its grammar at the `master` lockfile revision (`02b0165`, 2021) is built on tree-sitter-json 0.19, so its string nodes nest differently from `json`'s (see below).
- **`json5` gives other node names than `json`:** `file`, `member` with the fields `name` and `value`, and `identifier` for unquoted keys, where `json` gives `document`, `pair` with `key` and `value`. A rule that serves both parsers must name both.
- **Neovim gives `.json` → `json`, `.jsonc` → `jsonc`, `.json5` → `json5`.** PhpStorm's JSON globs in `data/catalog.json` have no `*.json5`, because JSON5 is a separate PhpStorm file type (`Json5FileType`, language `Json5Language extends JsonLanguage`).

## Parsers on each nvim-treesitter branch

| Parser | `master` at `cf12346` (pinned) | `main` at `37e52c7` |
| --- | --- | --- |
| `json` | [tree-sitter/tree-sitter-json](https://github.com/tree-sitter/tree-sitter-json) `46aa487` (2025-01-30), ABI 14 | same repo, `254c42a` (2026-08-17), ABI 14 |
| `jsonc` | [gitlab.com/WhyNotHugo/tree-sitter-jsonc](https://gitlab.com/WhyNotHugo/tree-sitter-jsonc) `02b0165` (2021-03-07), ABI 13 | removed |
| `json5` | [Joakker/tree-sitter-json5](https://github.com/Joakker/tree-sitter-json5) `ab0ba82` (2024-04-30), ABI 14 | same repo, `248b856` (2026-05-04), ABI 15 |

- `master`: `lua/nvim-treesitter/parsers.lua` (`list.json`, `list.jsonc`, `list.json5`) and `lockfile.json` for the revisions. `master` registers each parser for the filetype of the same name, so the filetype `jsonc` uses the `jsonc` parser and `json5` uses `json5`. Its queries `queries/jsonc/*.scm` start with `; inherits: json`.
- `main`: `lua/nvim-treesitter/parsers.lua` (revisions inline, both tier 2) and `plugin/filetypes.lua`, which has `json = { 'jsonc' }`: the filetype `jsonc` uses the `json` parser. `main` has no `jsonc` parser and no `runtime/queries/jsonc/`.
- The pinned `cf12346` is the tip of `master` ("docs(readme): list support upper bounds"). Its `README.md` says "Neovim 0.10 or 0.11 (Neovim 0.12 is **not supported**)".
- Changes between the two `json` revisions: one grammar change, `f1e4160` "grammar: allow plus-signed exponents": `{"a": 1e+5}` gives `(ERROR (UNEXPECTED 'e') (number))` with `json` on `master` and no error on `main` (`jsonc` and `json5` accept it). No corpus input has a `+` exponent. Between the two `json5` revisions: `966aaa2` "Fix grammar issues and add comprehensive test suite" lets `file` hold any value, adds `\x`, `\u` and line-continuation escapes in strings, and marks `comment` as `extra` in `node-types.json`.
- Neovim `v0.12.6` bundles no JSON parser (`$VIMRUNTIME/parser/` has `c`, `lua`, `markdown`, `markdown_inline`, `query`, `vim`, `vimdoc`).

## Parse results

How it was run: each grammar's `src/` at the revision above was taken with `git archive` and compiled with `cc -O2 -fPIC -shared src/parser.c` (no grammar has a `scanner.c`), the same files that nvim-treesitter compiles. Neovim `v0.12.6` ran headless with `-u NONE`, loaded each `.so` with `vim.treesitter.language.add(lang, { path = … })`, parsed each file with `vim.treesitter.get_string_parser`, walked the tree for `ERROR` nodes and `node:missing()`, and checked `root:has_error()`.

"ok" means no `ERROR` and no `MISSING` node. A failure gives the number of such nodes and the first one (line:column).

| Input | `json` master | `json` main | `jsonc` master | `json5` master | `json5` main |
| --- | --- | --- | --- | --- | --- |
| `blank_lines/blanks.json` | ok | ok | ok | ok | ok |
| `blank_lines/blanks_comments.json` | ok | ok | ok | ok | ok |
| `blank_lines/blanks_top.json` | ok | ok | ok | ok | ok |
| `spaces/comma_cases.json` | ok | ok | ok | ok | ok |
| `spaces/multiline.json` | ok | ok | ok | ok | ok |
| `spaces/oneline.json` | ok | ok | ok | ok | ok |
| `spaces/spaced_in.json` | ok | ok | ok | ok | ok |
| `tabs_and_indents/align.json` | ok | ok | ok | ok | ok |
| `tabs_and_indents/comments.json` | ok | ok | ok | ok | ok |
| `tabs_and_indents/continuation.json` | ok | ok | ok | ok | ok |
| `tabs_and_indents/empty_lines.json` | ok | ok | ok | ok | ok |
| `tabs_and_indents/mixed_in.json` | ok | ok | ok | ok | ok |
| `tabs_and_indents/nested.json` | ok | ok | ok | ok | ok |
| `tabs_and_indents/top_level.json` | ok | ok | ok | ok | ok |
| `wrapping_and_braces/align.json` | ok | ok | ok | ok | ok |
| `wrapping_and_braces/align_oneline.json` | ok | ok | ok | ok | ok |
| `wrapping_and_braces/comments.json` | ok | ok | ok | ok | ok |
| `wrapping_and_braces/json5_misc.json5` | FAIL 19, `ERROR` 2:1 | FAIL 19, `ERROR` 2:1 | FAIL 17, `ERROR` 2:1 | ok | ok |
| `wrapping_and_braces/long_array.json` | ok | ok | ok | ok | ok |
| `wrapping_and_braces/long_margin.json` | ok | ok | ok | ok | ok |
| `wrapping_and_braces/long_object.json` | ok | ok | ok | ok | ok |
| `wrapping_and_braces/long_string.json` | ok | ok | ok | ok | ok |
| `wrapping_and_braces/multiline_in.json` | ok | ok | ok | ok | ok |
| `wrapping_and_braces/nested_long.json` | ok | ok | ok | ok | ok |
| `wrapping_and_braces/r2_arrays_of_arrays.json` | ok | ok | ok | ok | ok |
| `wrapping_and_braces/r2_comments_align.json` | ok | ok | ok | ok | ok |
| `wrapping_and_braces/r2_scalars.json` | ok | ok | ok | FAIL 1, `ERROR` 1:1 | ok |
| `wrapping_and_braces/r2_strings.json` | ok | ok | ok | ok | ok |
| `wrapping_and_braces/r2_top_array.json` | ok | ok | ok | ok | ok |
| `wrapping_and_braces/r2_wrap_if_long_values.json` | ok | ok | ok | ok | ok |
| `wrapping_and_braces/short.json` | ok | ok | ok | ok | ok |
| `wrapping_and_braces/trailing.json` | FAIL 7, `MISSING number` 2:17 | FAIL 7, `MISSING number` 2:17 | FAIL 7, `MISSING number` 2:17 | ok | ok |
| `wrapping_and_braces/trailing.json5` | FAIL 14, `ERROR` 1:1 | FAIL 14, `ERROR` 1:1 | FAIL 15, `ERROR` 1:1 | ok | ok |
| **Inputs with no error** | **30 / 33** | **30 / 33** | **30 / 33** | **32 / 33** | **33 / 33** |

- Comments are in 6 inputs: `blanks_comments.json`, both `comments.json`, `r2_comments_align.json`, `trailing.json` and `json5_misc.json5`. `long_string.json` and `r2_strings.json` have `//` only inside strings. Every parser puts each comment in the tree as a `comment` node, also inside objects and arrays.
- How `json` recovers from a trailing comma: in an array it inserts `(MISSING number)` after the comma; in an object it adds an `(ERROR)` child. From `trailing.json` with `json` on `main`: `value: (array (number) (number) (number) (MISSING number))` and `value: (object (pair …) (pair …) (ERROR))`. So with `json`, the formatter sees a tree with errors for this input.
- `json` and `jsonc` accept several values at the top (`document` is `repeat($._value)`); `json5` accepts exactly one (`file` is one `_value` on `main`, an optional object or array on `master`).

## Node types and field names

From each build's `src/node-types.json`, checked against the parse trees (`node:sexpr()`). Punctuation is anonymous in all three: `{` `}` `[` `]` `,` `:`, and `"` in `json` and `jsonc`.

| Concept | `json` (master and main) | `jsonc` (master) | `json5` (master and main) |
| --- | --- | --- | --- |
| Root | `document`, children: any number of values and comments | `document`, same | `file`, one value (master: `object` or `array` only) |
| Object | `object`, children: `pair` | `object`, children: `pair` | `object`, children: `member` |
| Pair | `pair`, fields `key: string`, `value: _value` | `pair`, fields `key: string \| number`, `value: _value` | `member`, fields `name: string \| identifier`, `value: <any value>` |
| Array | `array`, children: values | `array`, children: values | `array`, children: values |
| Comment | `comment` (both `//` and `/* */`; extra) | `comment` (both; extra) | `comment` (both; extra) |
| String | `string`, children `string_content`, `escape_sequence` (`"a\"b"` → `(string (string_content) (escape_sequence) (string_content))`) | `string`, child `string_content`, which holds `escape_sequence` | `string`, one token with no children, `"…"` or `'…'` |
| Number | `number` (one token) | `number` | `number` (one token, also hex, `Infinity`, `NaN`, leading `+`/`.`) |
| Literals | `true`, `false`, `null` | `true`, `false`, `null` | `true`, `false`, `null` |
| Supertype | `_value` (`array`, `false`, `null`, `number`, `object`, `string`, `true`) | `_value` | none; `_value` is hidden |
| Unquoted key | n/a | n/a | `identifier` |

Example trees (Neovim `node:sexpr()`) of `tabs_and_indents/comments.json`:

```
json (main), jsonc (master):
(document (comment) (object (comment) (pair key: (string (string_content)) value: (number)) (comment) (comment)
  (pair key: (string (string_content)) value: (array (comment) (number) (comment) (number)))))
json5 (main):
(file (comment) (object (comment) (member name: (string) value: (number)) (comment) (comment)
  (member name: (string) value: (array (comment) (number) (comment) (number)))))
```

and of `wrapping_and_braces/json5_misc.json5` with `json5`:

```
(file (comment) (object (member name: (identifier) value: (number)) (member name: (string) value: (string)) …
  (member name: (identifier) value: (array (number) (number))) …))
```

## Filetypes

Neovim `v0.12.6`, `vim.filetype.match{ filename = … }` and `runtime/lua/vim/filetype.lua`:

- By extension: `json` → `json` (also `jsonp`, `geojson`, `webmanifest`, `ipynb`, `mcmeta`, and more), `jsonc` → `jsonc`, `json5` → `json5` (lines 702–719).
- By name: `.prettierrc`, `.stylelintrc`, `composer.lock`, `flake.lock`, `.swcrc` → `json`; `.babelrc`, `.eslintrc`, `.jshintrc`, `bun.lock` → `jsonc` (lines 1757–1776). By pattern: `[jt]sconfig*.json` and VS Code / VSCodium user settings → `jsonc` (lines 2776–2782).
- The corpus inputs: the 31 `.json` files → `json`; `json5_misc.json5` and `trailing.json5` → `json5`.

PhpStorm's JSON globs, `data/catalog.json` `languages.json.globs` (the same list as `docs/languages/json.md`):
`*.har`, `*.jsb2`, `*.jsb3`, `*.json`, `*.jsonc`, `*.postman_collection`, `*.postman_collection.json`, `*.postman_environment`, `*.postman_environment.json`, `.babelrc`, `.eslintrc`, `.prettierrc`, `.stylelintrc`, `.ws-context`, `composer.lock`, `jest.config`.

Neovim gives no filetype to `*.har`, `*.jsb2`, `*.jsb3`, `*.postman_collection`, `*.postman_environment`, `.ws-context` and `jest.config`: these are the names that a JSON `match(buf)` with `match_globs` would fill (Core ADR-0015). PhpStorm's globs have no `*.json5`: in IntelliJ Community, `json/src/com/intellij/json/json5/Json5FileType.java` is a separate file type named `JSON5` with the extension `json5`, and `Json5Language extends JsonLanguage` with permissive strings. The corpus still has two `.json5` inputs, which PhpStorm formatted with the JSON code style.

## Open points

- These runs used `.so` files compiled by hand from the pinned sources on Neovim `v0.12.6`, not `:TSInstall`. The parse depends only on `parser.c`, but the pinned `master` says it does not support Neovim 0.12.
- Whether a JSON spec lists `json5` (its own Language, Core ADR-0015 "Family maps decide … `json5`") and which parser serves `jsonc` is a design question for the map, not answered here.
