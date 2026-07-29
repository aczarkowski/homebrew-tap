class Repoglean < Formula
  desc "Safely reclaim space from regenerable Git artifacts"
  homepage "https://github.com/aczarkowski/RepoGlean"
  license "MIT"

  livecheck do
    url :stable
    strategy :github_latest
  end

  uses_from_macos "git"

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/aczarkowski/RepoGlean/releases/download/v2.1.0/repoglean-osx-arm64.tar.gz"
      sha256 "1fab993bf4d16b9b3883496fadd280b3028a7d0f30747979f2a69e441d5d2a8e"
    else
      url "https://github.com/aczarkowski/RepoGlean/releases/download/v2.1.0/repoglean-osx-x64.tar.gz"
      sha256 "566dba96081e2f507035021016046363319cd2afa1a33f6c84548eeac6b1bd32"
    end
  end

  on_linux do
    if Hardware::CPU.arm?
      url "https://github.com/aczarkowski/RepoGlean/releases/download/v2.1.0/repoglean-linux-arm64.tar.gz"
      sha256 "e3ec6c049d6aa0b02755b899eee3226341891f2e2bcf234a36ed4c6d99c878b6"
    else
      url "https://github.com/aczarkowski/RepoGlean/releases/download/v2.1.0/repoglean-linux-x64.tar.gz"
      sha256 "4d3d34ac5f31722bc521ac3c4b1fc019f892406d512ff469d2830a94d5ad3acb"
    end
  end

  def install
    bin.install "repoglean"
  end

  test do
    assert_equal "repoglean #{version}\n", shell_output("#{bin}/repoglean --version")
  end
end
