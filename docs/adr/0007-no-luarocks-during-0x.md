# No LuaRocks during 0.x

During 0.x, the Core and the Language Plugins release only as Git tags and GitHub releases ([ADR-0004](0004-public-0x-releases-cut-from-git-flow-branches.md)). They have no rockspec, no LuaRocks secret and no LuaRocks job, and `release.yml`, which the template copies unchanged, gets no LuaRocks step. We decide again at Core 1.0 ("Do the Core and the Language Plugins publish to LuaRocks?", [#13](https://github.com/a1exk-dev/codestyle-home/issues/13)).

Only rocks.nvim installs from luarocks.org, and its README asks new users to wait for its v3 rewrite. lazy.nvim and `vim.pack` install from Git ([findings](https://github.com/a1exk-dev/codestyle.nvim/blob/research/luarocks-publishing/docs/research/luarocks-publishing.md), [codestyle.nvim#86](https://github.com/a1exk-dev/codestyle.nvim/issues/86)). Until Core 1.0, rocks.nvim users add the repos with rocks-git.nvim.

## Considered Options

- **Publish now, with a luarocks.org API key in each repo.** Rejected: it adds a secret to each of the 17 repos and a manual step to each new plugin, because a template copies no secrets.
- **The NURR bot uploads the rocks.** Not ours to choose: NURR may list us without our help.
- **No LuaRocks during 0.x.** Chosen.

## Consequences

- A rockspec cannot give lazy.nvim users their parsers either: lazy.nvim never puts a parser rock on the runtimepath, a plain Language Plugin's rockspec makes it clone the grammar's C source instead, and a `lazy.lua` hides the rockspec ("Can a plugin's rockspec make lazy.nvim install its Tree-sitter parsers?", [#62](https://github.com/a1exk-dev/codestyle-home/issues/62)).
