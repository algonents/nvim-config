# nvim-config
A minimalist nvim configuration for mixed-mode Rust/C++ development

## Installing Neovim (AppImage)

Neovim runs straight from the official AppImage — no distro package, no
extraction. Requires Neovim 0.11+.

| Piece   | Location                                           |
|---------|----------------------------------------------------|
| Binary  | `~/.local/opt/nvim-linux-x86_64.appimage`          |
| Command | `~/.local/bin/nvim` → symlink to the AppImage      |
| Config  | `~/.config/nvim` → symlink to this repo            |

Running the AppImage directly needs FUSE 2 (`fuse-libs` on Fedora/RHEL,
`libfuse2` on Debian/Ubuntu).

```shell
mkdir -p ~/.local/opt ~/.local/bin
curl -Lo ~/.local/opt/nvim-linux-x86_64.appimage \
  https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.appimage
chmod u+x ~/.local/opt/nvim-linux-x86_64.appimage
ln -s ~/.local/opt/nvim-linux-x86_64.appimage ~/.local/bin/nvim
ln -s ~/Repos/nvim-config ~/.config/nvim
```

**Upgrading:** re-run the `curl` + `chmod` lines to overwrite the AppImage; the
symlink keeps working.

**No FUSE?** Extract it instead and point the symlink at the extracted binary:

```shell
cd ~/.local/opt && ./nvim-linux-x86_64.appimage --appimage-extract
ln -sf ~/.local/opt/squashfs-root/usr/bin/nvim ~/.local/bin/nvim
```
