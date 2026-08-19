# offpolicy/homebrew-tap

Personal Homebrew tap. Currently one formula.

## mosh

A fork of homebrew-core's `mosh` carrying a small patch series that restores
terminal features upstream mosh silently drops.

mosh is a terminal emulator in the middle: `mosh-server` parses the application's
output into a framebuffer and ships a diff, and `mosh-client` re-parses and
re-renders it. Any escape sequence mosh doesn't implement is **discarded** and
never reaches your real terminal.

### Patch series

| # | Feature | Source |
|---|---|---|
| 0001 | SGR 2 faint/dim + SGR 9 strikethrough | upstream [PR #1380](https://github.com/mobile-shell/mosh/pull/1380), verbatim |
| 0002 | `static_assert` that `attribute_type` still fits the bitfield | ours |
| 0003 | Cursor shape (DECSCUSR, `CSI Ps SP q`) | upstream [PR #1355](https://github.com/mobile-shell/mosh/pull/1355), rebased + bugfixed |

**0001** — `faint` existed in the `Renditions` enum but `set_rendition()` had no
`case 2:` and `sgr()` never emitted `";2"`; strikethrough was absent entirely.
Concretely, Claude Code renders its ghost text with `ESC[2m` and no colour, so
over mosh the suggestion arrived in the same white as typed input. Colours were
never affected — mosh passes 16/256/24-bit colour through fine.
(Refs [#1276](https://github.com/mobile-shell/mosh/issues/1276).)

**0002** — strikethrough fills `attributes : 8` exactly (`SIZE == 8`). A ninth
attribute would be silently truncated and show up as a rendition that never
renders, rather than a build error. Widening to `:14` would still fit, since
`25 + 25 + 14 == 64`.

**0003** — mosh registers no dispatch for final byte `q` at all, so nvim's
insert-mode bar cursor stayed a block. PR #1355 does not apply cleanly to master
(the OSC 8 merge extended the same `DrawState::operator==` line), and it carries
a bug its maintainer flagged and the author never fixed: `-1` is the "never set"
sentinel and `Framebuffer::reset()` (RIS, `\033c`) returns to it, but the emit is
guarded by `!= -1`, so after a reset the terminal keeps the old shape while mosh
believes it is default. Repro: `printf '\033[6 q\033c'`. We emit DECSCUSR 0 on
the way back to `-1`. (Refs [#352](https://github.com/mobile-shell/mosh/issues/352),
open since 2012.)

### Built from pinned master, not the 1.4.0 tarball

mosh's last release is 1.4.0 (2022-10-31) and master has moved on without a new
one. Building the release tarball meant hand-porting every patch to 1.4.0's older
formatting, because upstream reformatted the terminal sources afterwards.

The formula pins an exact master commit instead
(`decd9b705eb81626f694335b8d5940538beb06da`, master HEAD as of 2026-08-19), so:

- upstream patches apply **verbatim** — no hand-porting
- **OSC 8 hyperlink support comes for free** ([PR #1360](https://github.com/mobile-shell/mosh/pull/1360),
  merged 2026-03-22). It is absent from 1.4.0, so mosh was silently dropping
  Claude Code's links on macOS while they worked fine to a Linux box on a
  git-master build.
- it matches what the Linux side of the fleet already builds, so both ends of a
  session run identical code

The pin is deliberate. Bump it consciously; do not float it.

### Install

```sh
brew uninstall mosh                 # remove homebrew-core's keg first
brew install offpolicy/tap/mosh
```

The qualified name is required: homebrew-core always wins the bare name `mosh`.

**Verify the install receipt**, don't trust brew's output:

```sh
jq -r .source.tap /opt/homebrew/Cellar/mosh/*/INSTALL_RECEIPT.json   # => offpolicy/tap
```

A receipt naming a tap that no longer exists makes brew fall back to the bare
name and silently reinstall core's **unpatched** mosh. `brew reinstall` can also
keep a stale tap in the receipt when two taps are present; `brew untap --force`
plus a fresh install is what actually rewrites it.

### Both ends must be patched

Parse and emit both run on each end, so the fixes are only visible when the
client and the server both carry them. Mixing is safe: the state-sync protobuf
carries opaque bytes and never a structured rendition, so an unpatched parser
just ignores the extra attributes rather than desyncing.

### Maintenance

- Adding or editing a patch needs only a `revision` bump — patch files take no
  `sha256`, so there is no checksum churn.
- Refreshing a patch from upstream is `gh pr diff <n> > Patches/<file>`.
- `.github/` is gitignored on purpose: `brew tap-new`'s autobump workflow would
  bump the formula and undo the commit pin.
- The recurring cost is dependency churn, not upstream releases — homebrew-core's
  mosh sat at `revision 40` against one tarball. When protobuf or OpenSSL break
  linkage, bump `revision` and rebuild.
- Do **not** run `brew audit` here; it installs a dev gem bundle that has broken
  this Homebrew installation before.
