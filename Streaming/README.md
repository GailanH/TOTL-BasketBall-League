# TOTL stream overlay

`overlay.html` is the on-screen graphic for streaming game nights to Twitch and YouTube. It draws a score bug at the bottom of the frame that expands into a live box score, plus pop-ups for big plays, final scores and rank-ups. It's a single file with no build step and no dependencies.

**Status: prototype (iteration 23).** It runs on a made-up demo game. Connecting it to real games needs the backend (ROADMAP D5).

## What viewers see

- **Score bug:** both teams, their average tier, the score, court and game number, and a "first to 21" target. Shows FINAL with the winner checked when the game ends.
- **Box score:** expands up out of the bug. It shows PTS, REB, AST, BLK and STL per player, each player's tier, and **RP pace**: the Ranked Points each player would earn if the game ended now. The projected MVP and SVP are tagged. After the final whistle the column becomes **RP** and the box score opens on its own.
- **Pop-ups (top right):** 3-pointers, blocks, steals, the final score, and rank-ups.

Twitch and YouTube viewers can't click on a stream, so the box score is opened by whoever runs the stream (hotkey), or on a timer (auto-cycle).

## Try it

Open `overlay.html` in a browser. Outside OBS it shows a fake court and a control panel.

## OBS setup

1. Install OBS Studio (free).
2. Scene: add the camera (Video Capture Device), then **Sources → + → Browser**.
3. Tick **Local file** and choose `overlay.html`, or untick it and paste a URL with options (see below). Width **1920**, height **1080**. Leave "Shutdown source when not visible" off.
4. Put the Browser source **above** the camera in the source list.
5. To use the hotkeys, right-click the Browser source → **Interact**, and press the keys in that window.
6. Streaming to Twitch and YouTube at once: check each platform's current rules first. Then either use a multistream service (e.g. Restream) or an OBS multi-output plugin.

### Hotkeys

| Key | Action |
|---|---|
| B | Box score, both teams (press again to close) |
| 1 / 2 | Box score for Team A / Team B only |
| C | Auto-cycle on/off |
| Esc | Close the box score |
| N, P, F | Demo only: next play, pause, end the game |

### URL options

Add them to the file path or URL, e.g. `overlay.html?court=2&cycle=90`.

| Option | Default | Meaning |
|---|---|---|
| `court` | 1 | Which court's game to show. Use one Browser source (or one stream) per court. |
| `cycle` | 0 | Open the box score every N seconds. 0 means the operator opens it manually. |
| `hold` | 12 | How many seconds an auto-opened box score stays up. |
| `feed` | demo | Data source. Only `demo` exists until the backend is live. |
| `speed` | 2.2 | Demo only: seconds between made-up plays. |
| `preview` | auto | `1` forces the fake court and controls on, `0` forces them off. |

## Connecting real games (after D5)

The overlay only displays what a **feed** gives it. Today that's `DemoFeed`. The plan:

1. The scorekeeper records stats live in the app during the game, instead of only after it.
2. The app writes the in-progress game to the backend (one row per court), including **RP pace from `MatchScoring`**. The overlay must never compute RP itself; the demo's estimate is only there for testing.
3. A `BackendFeed` in `overlay.html` subscribes to that row and passes it to the overlay.

Each update must have this shape:

```json
{
  "court": 1, "gameNumber": 3, "target": 21, "status": "live",
  "teams": {
    "A": { "name": "TEAM A", "color": "#f4f4f4", "score": 13, "avgTier": "Silver I",
           "players": [ { "id": "p1", "name": "M. Ortiz", "tier": "Silver I",
                          "stats": { "pts": 6, "reb": 2, "ast": 1, "blk": 0, "stl": 1 },
                          "rpPace": 12, "tag": "MVP" } ] },
    "B": { "...": "same shape" }
  },
  "events": [ { "id": 41, "type": "play", "text": "C. Brooks", "badge": "3PT", "sub": "From deep", "team": "B" },
              { "id": 42, "type": "rankup", "text": "D. Kim", "tier": "Silver II", "sub": "Ranked up to Silver II" },
              { "id": 43, "type": "final", "text": "Final · Team A wins", "sub": "21 – 17" } ]
}
```

- `status` is `live` or `final`. `rpPace` is `null` when the game is tied. `tag` is `MVP`, `SVP` or `null`.
- `events` must have increasing `id`s. The overlay shows each new one once.
- The app's 2-day stat check still applies: anything shown on stream is provisional until confirmed.
