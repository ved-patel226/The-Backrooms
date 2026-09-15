# The Backrooms

A first-person Backrooms walking sim built in **Godot 4.3** (GDScript). 

The level is generated at startup and streamed around the player in chunks, so
every run has a different floor plan.

![A dark Backrooms corridor: the flashlight cone falls across a yellowed wall while
two ceiling panels glow further down the hall, the whole frame heavy with grain and
vignette.](preview.png)

## Controls

| Input | Action |
| --- | --- |
| `W` `A` `S` `D` / arrow keys | Move |
| Mouse | Look |
| `Shift` | Sprint (triggers exertion breathing) |
| `F` | Toggle flashlight |

Gamepad left stick / d-pad also moves, since movement is bound to the default
`ui_*` actions.

> The mouse is captured on start and nothing releases it in game. Press `F8` to
> stop a run from the editor, or `Esc` to break pointer lock in a browser.

## Running it

**Editor:** open the project folder in Godot 4.3 and press `F5`. The main scene is
`World.tscn`.

**Web:** the project ships a `Web` export preset that writes to `build/index.html`.
Export it, then serve the folder over HTTP — it will not run from a `file://` URL:

```sh
python -m http.server --directory build 8000
```

The preset has `thread_support=false`, so no cross-origin isolation headers are
needed.

Desktop uses the **Mobile** renderer; web falls back to **Compatibility**.
