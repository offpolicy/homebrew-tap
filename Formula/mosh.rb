class Mosh < Formula
  desc "Remote terminal application (patched: SGR 2 faint support)"
  homepage "https://mosh.org"
  url "https://github.com/mobile-shell/mosh/releases/download/mosh-1.4.0/mosh-1.4.0.tar.gz"
  sha256 "872e4b134e5df29c8933dff12350785054d2fd2839b5ae6b5587b14db1465ddd"
  license "GPL-3.0-or-later"
  revision 41

  # Fork of homebrew-core's mosh.rb (revision 40) carrying one local patch.
  #
  # Upstream mosh silently discards the SGR 2 "faint"/dim attribute: `faint`
  # exists in the Renditions enum but there is no `case 2:` in set_rendition()
  # and sgr() never emits ";2". Anything styled dim therefore arrives at the
  # local terminal as normal-intensity text. This breaks, among other things,
  # Claude Code's grey ghost text, which becomes indistinguishable from typed
  # input.
  #
  # Upstream PR: https://github.com/mobile-shell/mosh/pull/1404 (open)
  # Upstream issue: https://github.com/mobile-shell/mosh/issues/1276 (open since 2023)
  #
  # That PR targets master, whose terminalframebuffer.cc has been reformatted
  # since the 1.4.0 release, so it does not apply to the release tarball. The
  # patch below is the same change hand-ported to 1.4.0's formatting; the
  # semantics are identical, including `case 22` cancelling bold AND faint.
  #
  # NOTE: this patch is written against the 1.4.0 tarball and will NOT apply to
  # a --HEAD build. Bump `revision` whenever this patch changes.
  patch :DATA

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

    # `configure` does not recognise `--disable-debug` in `std_configure_args`.
    system "./configure", "--prefix=#{prefix}", "--enable-completion", "--disable-silent-rules"
    system "make", "install"
  end

  test do
    system bin/"mosh-client", "-c"
  end
end

__END__
--- a/src/terminal/terminalframebuffer.cc
+++ b/src/terminal/terminalframebuffer.cc
@@ -491,7 +491,10 @@
 
   bool value = num < 9;
   switch ( num ) {
-  case 1: case 22: set_attribute(bold, value); break;
+  case 1: set_attribute(bold, value); break;
+  case 2: set_attribute(faint, value); break;
+  case 22: /* cancels both bold and faint */
+    set_attribute(bold, value); set_attribute(faint, value); break;
   case 3: case 23: set_attribute(italic, value); break;
   case 4: case 24: set_attribute(underlined, value); break;
   case 5: case 25: set_attribute(blink, value); break;
@@ -526,6 +529,7 @@
 
   ret.append( "\033[0" );
   if ( get_attribute( bold ) ) ret.append( ";1" );
+  if ( get_attribute( faint ) ) ret.append( ";2" );
   if ( get_attribute( italic ) ) ret.append( ";3" );
   if ( get_attribute( underlined ) ) ret.append( ";4" );
   if ( get_attribute( blink ) ) ret.append( ";5" );
