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
      url "https://github.com/aczarkowski/RepoGlean/releases/download/v2.2.0/repoglean-osx-arm64.tar.gz"
      sha256 "93f6d22258638e7f9505a7ac720906d67d8417b33d9a6afcfab877fa243fe8be"
    else
      url "https://github.com/aczarkowski/RepoGlean/releases/download/v2.2.0/repoglean-osx-x64.tar.gz"
      sha256 "1f2a1e563a48a4716f504a0df64a588aceb7638e98c2d71af3f0cc699caaa424"
    end
  end

  on_linux do
    if Hardware::CPU.arm?
      url "https://github.com/aczarkowski/RepoGlean/releases/download/v2.2.0/repoglean-linux-arm64.tar.gz"
      sha256 "a8a8bd3eb736bca3a71a4e39f51c47697c875f23525ec1eabc08374f2d6bb744"
    else
      url "https://github.com/aczarkowski/RepoGlean/releases/download/v2.2.0/repoglean-linux-x64.tar.gz"
      sha256 "b0a17335e863aff90f0726113d0cf4066ec5430d12ba04bb8366403c922de7e1"
    end
  end

  def install
    bin.install "repoglean"
  end

  test do
    assert_equal "repoglean #{version}\n", shell_output("#{bin}/repoglean --version")
  end
end
