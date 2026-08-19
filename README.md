# ohjoonhee/homebrew-tap

Personal Homebrew tap. Currently one formula.

## mosh

A fork of homebrew-core's `mosh` carrying a single local patch: **support for the
SGR 2 "faint"/dim rendition**.

### Why

Upstream mosh silently discards `ESC[2m`. `faint` exists in the `Renditions`
enum, but `set_rendition()` has no `case 2:` and `sgr()` never emits `";2"`, so
the attribute is neither parsed nor re-emitted. Anything styled dim arrives at
the local terminal as normal-intensity text.

Concretely: Claude Code renders its input-prompt ghost text with `ESC[2m` and no
explicit colour, so over mosh the suggestion appears in the same white as typed
input. Colours are unaffected — mosh passes 16/256/24-bit colour through
correctly — so this is specific to the dim attribute.

- Upstream issue: https://github.com/mobile-shell/mosh/issues/1276 (open since 2023)
- Upstream PR: https://github.com/mobile-shell/mosh/pull/1404 (open)

### Why the patch is hand-ported rather than fetched

PR #1404 targets `master`, whose `terminalframebuffer.cc` has been reformatted
since the 1.4.0 release. It does **not** apply to the 1.4.0 tarball Homebrew
builds — both hunks fail. The embedded patch is the same change ported to
1.4.0's formatting, with identical semantics, including `case 22` cancelling
both bold and faint (`bool value = num < 9` makes `2` set and `22` clear).

### Install

```sh
brew uninstall mosh                 # remove homebrew-core's keg first
brew install ohjoonhee/tap/mosh
```

The qualified name is required: homebrew-core always wins the bare name `mosh`.
Once installed, the keg records `tap: ohjoonhee/tap` in its install receipt, so
`brew upgrade` re-resolves against this tap and core's mosh is never consulted.

### Both ends must be patched

mosh-server renders a framebuffer diff into an escape-sequence string and sends
it as `hostbytes`; mosh-client re-parses that into its own framebuffer and
re-renders locally. Both the parse (`case 2:`) and the emit (`";2"`) therefore
run on each end. A patched machine talking to an unpatched one is safe — the
extra `;2` is ignored by an old parser — but the fix is only visible when both
ends carry it.

### Maintenance

- Bump `revision` whenever the embedded patch changes.
- The recurring cost is dependency churn, not upstream releases: homebrew-core's
  mosh sat at `revision 40` against this same 1.4.0 tarball. When protobuf or
  OpenSSL break linkage, bump `revision` and rebuild.
- mosh releases roughly once every 4-5 years (1.4.0 was 2022-10-31; nothing
  since), so upstream rebasing is rare.
- The patch will not apply to a `--HEAD` build.
