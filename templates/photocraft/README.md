# Image-editing workspace

Pinned to the `photocraft` environment of [nix-labs](https://github.com/whifflash/nix-labs):
[PhotoCraft](https://github.com/storytold/photocraft), an open-source, clean-room
reimplementation of Photoshop in Rust. Layers, masks, adjustment layers, layer styles, type,
vectors and real PSD/PSB files. It is early alpha, so keep your originals.

Every menu item is an engine command, and the app, the CLI and the agent all run the same ones.
So an edit you work out by hand can be replayed over a folder, or handed to an agent.

```sh
direnv allow                  # or: nix develop

photocraft photo.psd          # the desktop app

# One file, headless: open, edit, save
photocraft-cli run photo.psd \
  --cmd layer.newAdjustmentLayer.curves --params '{"points":[[0,0],[64,48],[192,212],[255,255]]}' \
  --out photo-graded.png

# A whole folder: sharpen, Curves, Vibrance (actions/grade.json)
photocraft-cli batch --actions actions/grade.json --in raw --out graded --format png

photocraft-cli commands --filter vibrance   # find a command id and its parameters
photocraft-cli info photo.psd               # layer tree, size, depth, colour mode
```

An action list is a JSON array of `[command, params]` pairs. An action recorded in the app's
Actions panel or a Photoshop `.atn` set plays the same way (`--action <name>` picks one).

The agent side is wired up in `.mcp.json` / `opencode.json`. The server is rooted at this
directory, so it can open and save files here and nowhere else. It can list and run commands,
inspect the layer tree, and render previews as images, so it can look at its own edits. To
drive the running app instead, start `photocraft --control 7878 --control-token-file
.private/control.token` and append `--bridge 127.0.0.1:7878 --control-token-file
.private/control.token` to the server's arguments.

Re-pin the environment: `nix flake update nix-labs`.
