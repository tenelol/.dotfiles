# Graph Report - config  (2026-05-01)

## Corpus Check
- Corpus is ~10,992 words - fits in a single context window. You may not need a graph.

## Summary
- 161 nodes · 204 edges · 10 communities detected
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Web Tooling|Web Tooling]]
- [[_COMMUNITY_Live Preview Server|Live Preview Server]]
- [[_COMMUNITY_Terminal Workflow|Terminal Workflow]]
- [[_COMMUNITY_PlatformIO Commands|PlatformIO Commands]]
- [[_COMMUNITY_Project Root Detection|Project Root Detection]]
- [[_COMMUNITY_Hammerspoon Input|Hammerspoon Input]]
- [[_COMMUNITY_SCSS Watcher|SCSS Watcher]]
- [[_COMMUNITY_Nix Plugin Loader|Nix Plugin Loader]]
- [[_COMMUNITY_Test Terminal|Test Terminal]]
- [[_COMMUNITY_Telescope Project Search|Telescope Project Search]]

## God Nodes (most connected - your core abstractions)
1. `run_pio()` - 11 edges
2. `PreviewState` - 8 edges
3. `PreviewHandler` - 8 edges
4. `M.show()` - 7 edges
5. `open_cli()` - 7 edges
6. `M.cycle()` - 7 edges
7. `terminal_module()` - 6 edges
8. `M.new()` - 6 edges
9. `start_tsc_watch()` - 6 edges
10. `start_scss_watch()` - 6 edges

## Surprising Connections (you probably didn't know these)
- None detected - all connections are within the same source files.

## Communities

### Community 0 - "Web Tooling"
Cohesion: 0.19
Nodes (21): compile_scss_target(), current_file_path(), current_scss_target(), find_typescript_config(), get_tsc_watch_terminal(), infer_scss_entrypoint(), open_current_file_in_browser(), open_in_browser() (+13 more)

### Community 1 - "Live Preview Server"
Cohesion: 0.15
Nodes (7): BaseHTTPRequestHandler, main(), parse_args(), PreviewHandler, PreviewServer, PreviewState, ThreadingHTTPServer

### Community 2 - "Terminal Workflow"
Cohesion: 0.26
Nodes (17): close_other_terminals(), M.claude(), M.codex(), M.cycle(), M.new(), M.next(), M.previous(), M.select() (+9 more)

### Community 3 - "PlatformIO Commands"
Cohesion: 0.29
Nodes (12): ensure_platformio(), get_terminal(), M.build(), M.clean(), M.compiledb(), M.init(), M.monitor(), M.upload() (+4 more)

### Community 4 - "Project Root Detection"
Cohesion: 0.57
Nodes (7): M.buffer_path(), M.buffer_root(), M.cwd_root(), M.root(), normalize(), start_dir(), stat()

### Community 5 - "Hammerspoon Input"
Cohesion: 0.43
Nodes (5): switchToEnglish(), switchToJapanese(), systemZoomHotkeysEnabled(), toggleIme(), toggleSystemZoom()

### Community 6 - "SCSS Watcher"
Cohesion: 0.7
Nodes (4): compile_once(), main(), parse_args(), scan_latest()

### Community 7 - "Nix Plugin Loader"
Cohesion: 0.83
Nodes (3): M.dep(), M.spec(), plugin_dir()

### Community 8 - "Test Terminal"
Cohesion: 0.83
Nodes (3): get_terminal(), M.run(), M.toggle()

### Community 9 - "Telescope Project Search"
Cohesion: 1.0
Nodes (3): project_find_files(), project_git_files(), project_opts()

## Suggested Questions
_Not enough signal to generate questions. This usually means the corpus has no AMBIGUOUS edges, no bridge nodes, no INFERRED relationships, and all communities are tightly cohesive. Add more files or run with --mode deep to extract richer edges._