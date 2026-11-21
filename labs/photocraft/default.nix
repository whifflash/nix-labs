# Image editing with PhotoCraft: the open-source, clean-room Photoshop
# reimplementation in pure Rust (pkgs/photocraft.nix — not in nixpkgs).
#
# Everything the editor can do is one of 500+ engine commands, and the UI, the
# CLI and the MCP server all run the same ones. So the lab is three ways into
# one engine: the desktop app for working by hand, `photocraft-cli` for
# scripted and batch edits (an action list over a folder), and the MCP server
# for letting an agent do either.
{
  pkgs,
  lib,
  labPkgs,
}:
{
  photocraft = {
    packages = [
      labPkgs.photocraft # photocraft (GUI) + photocraft-cli (headless)
      labPkgs.mcp-photocraft # agent access: commands, layer tree, previews as images
    ];

    shellHook = ''
      echo "  edit:    photocraft image.psd"
      echo "  script:  photocraft-cli run in.psd --cmd <id> --params '{…}' --out out.png"
      echo "  batch:   photocraft-cli batch --actions actions/grade.json --in raw --out graded --format png"
      echo "  find:    photocraft-cli commands --filter curves     (every menu item is a command)"
      echo "  agent:   lab mcp photocraft --write"
      ${lib.optionalString pkgs.stdenv.hostPlatform.isLinux ''
        echo "  note:    the GPU comes from the host's Vulkan/EGL drivers — on NixOS hardware.graphics"
      ''}
    '';
  };
}
