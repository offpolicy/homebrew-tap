class Mosh < Formula
  desc "Remote terminal application (patched: faint, strikethrough, cursor shape)"
  homepage "https://mosh.org"
  # Built from a PINNED master commit, not the 1.4.0 release tarball.
  #
  # mosh's last release was 1.4.0 (2022-10-31) and master has moved on without a
  # new release. Building the release tarball meant every patch we carry had to be
  # hand-ported to 1.4.0's older formatting, because upstream reformatted the
  # terminal sources afterwards. Pinning to master instead means upstream patches
  # apply VERBATIM, and it matches what home-machine's Ubuntu build already uses,
  # so both ends of a mosh session run identical code.
  #
  # It also brings OSC 8 hyperlink support (PR #1360, merged 2026-03-22) for free.
  # That is absent from 1.4.0, so Claude Code's links were silently dropped by mosh
  # on macOS while working fine to the Linux box.
  #
  # decd9b7 is master HEAD as of 2026-08-19 (and is itself the OSC 8 merge).
  # Bump this deliberately; do not float it.
  url "https://github.com/mobile-shell/mosh.git",
      revision: "decd9b705eb81626f694335b8d5940538beb06da"
  version "1.4.0-decd9b7"
  license "GPL-3.0-or-later"
  revision 44

  # Patch series, applied in order. Each file is a diff taken straight from the
  # named upstream PR, so refreshing one is `gh pr diff <n> > Patches/<file>`.
  # Homebrew resolves these relative to the tap root and takes no sha256, so
  # editing a patch needs no checksum bump — only a `revision` bump above.
  #
  # NOTE: mosh renders a framebuffer diff into an escape-sequence string on the
  # server and re-parses it on the client, so BOTH ends must carry these patches.
  # They are display-only: the state-sync protobuf ships opaque bytes and never a
  # structured rendition, so a patched end talking to an unpatched one degrades
  # gracefully rather than desyncing.

  # Upstream drops the SGR 2 "faint" and SGR 9 "strikethrough" attributes
  # entirely: `faint` exists in the Renditions enum but set_rendition() has no
  # `case 2:` and sgr() never emits ";2", and strikethrough is absent altogether.
  # Anything dim arrives at normal intensity — which made Claude Code's grey ghost
  # text indistinguishable from typed input — and struck-through text arrives
  # plain, which affects nvim's DiagnosticUnderlineDeprecated among others.
  #
  # This is PR #1380, which is a strict superset of the narrower faint-only PR
  # #1404 we used to carry. It was independently verified by a third party across
  # a 77k-combination attribute sweep.
  # https://github.com/mobile-shell/mosh/pull/1380 (open)
  # https://github.com/mobile-shell/mosh/issues/1276 (open since 2023)
  patch do
    file "Patches/0001-sgr-2-faint-and-9-strikethrough.patch"
  end

  # Ours, not upstream: strikethrough fills the attributes bitfield exactly, so
  # guard the next addition with a compile-time check instead of silent truncation.
  patch do
    file "Patches/0002-static-assert-attributes-fit.patch"
  end

  # Cursor shape (DECSCUSR, `CSI Ps SP q`). mosh registers no dispatch for final
  # byte `q` at all, so nvim's insert-mode bar cursor stays a block over mosh.
  #
  # PR #1355 rebased onto decd9b7 — it does NOT apply cleanly, because the OSC 8
  # merge extended the same DrawState::operator== line — plus a fix for the reset
  # bug upstream's maintainer flagged and the author never addressed: RIS (\033c)
  # returns cursor_shape to the -1 "unset" sentinel, which upstream's emit guard
  # skips, so the terminal keeps the old shape while mosh thinks it is default.
  # https://github.com/mobile-shell/mosh/pull/1355 (open, conflicting upstream)
  # https://github.com/mobile-shell/mosh/issues/352 (open since 2012)
  patch do
    file "Patches/0003-cursor-shape-decscusr.patch"
  end

  depends_on "autoconf" => :build # ./autogen.sh -> autoreconf -fi
  depends_on "automake" => :build
  depends_on "pkgconf" => :build
  depends_on "protobuf"

  uses_from_macos "ncurses"

  on_macos do
    depends_on "tmux" => :build # for `make check`
  end

  on_linux do
    depends_on "openssl@3" # Uses CommonCrypto on macOS
    depends_on "zlib-ng-compat"
  end

  def install
    # https://github.com/protocolbuffers/protobuf/issues/9947
    ENV.append_to_cflags "-DNDEBUG"
    # Avoid over-linkage to `abseil`.
    ENV.append "LDFLAGS", "-Wl,-dead_strip_dylibs" if OS.mac?

    # teach mosh to locate mosh-client without referring
    # PATH to support launching outside shell e.g. via launcher
    inreplace "scripts/mosh.pl", "'mosh-client", "'#{bin}/mosh-client"

    # Keep C++ standard in sync with abseil.rb.
    # Use `gnu++17` since Mosh allows use of GNU extensions (-std=gnu++11).
    ENV.append "CXXFLAGS", "-std=gnu++17"

    # A git checkout has no generated `configure`; the release tarball did.
    system "./autogen.sh"

    # `configure` does not recognise `--disable-debug` in `std_configure_args`.
    system "./configure", "--prefix=#{prefix}", "--enable-completion", "--disable-silent-rules"
    system "make", "install"
  end

  test do
    system bin/"mosh-client", "-c"
  end
end
