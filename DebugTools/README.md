# DebugTools: testing only

Everything here exists only to try the app with realistic data. It's compiled into **Debug builds only** (every file is wrapped in `#if DEBUG`), so it never ships, and nothing in the real app depends on it. **Don't build features on top of it.** Real members always create their own account and password through sign-up.

| File | What it does |
|---|---|
| `DemoData.swift` | Launch arguments for UI tests and demos: `-uiTesting` (fresh in-memory database), `-seedDemoData` (sample league), `-loginAs <username>`. |
| `SampleLeague.swift` | A built-in 16-player league plus 18 games (all test passwords: `totl-demo-123`). |
| `SampleLeagueButton.swift` | The orange "Load Sample League" button on Edit Player Accounts. |

## How to remove it

1. Delete the `DebugTools/` folder, `Tests/SampleLeagueTests.swift`, and `UITests/` (the UI tests use the demo launch arguments).
2. Delete the three blocks marked `#if DEBUG // DebugTools` in `ContentView.swift`, `Persistence.swift`, and `EditAccountsView.swift`.
3. In `project.yml`, remove the `Project_Comp_BUITests` target and its scheme entries, then run `xcodegen generate`.

The games CSV import on Record Game is a **real** staff feature (for statisticians) and stays.
