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
      url "https://github.com/aczarkowski/RepoGlean/releases/download/v2.3.1/repoglean-osx-arm64.tar.gz"
      sha256 "45bc42106643ac7d3334ccab981a53a729acdc44922bedd49999122ac6156270"
    else
      url "https://github.com/aczarkowski/RepoGlean/releases/download/v2.3.1/repoglean-osx-x64.tar.gz"
      sha256 "bfdafbca28eb1a7b522b6f0cda76f82b2c42b591804edba7041e8dda66c4baff"
    end
  end

  on_linux do
    if Hardware::CPU.arm?
      url "https://github.com/aczarkowski/RepoGlean/releases/download/v2.3.1/repoglean-linux-arm64.tar.gz"
      sha256 "a53cadaada2661a3d45745c981828b0c71d586f9f697e9759150912aa418115f"
    else
      url "https://github.com/aczarkowski/RepoGlean/releases/download/v2.3.1/repoglean-linux-x64.tar.gz"
      sha256 "16b507d805e5a6da4899ca5150d82df72de166723288c8cdad31e1bef548347a"
    end
  end

  def install
    bin.install "repoglean"
  end

  test do
    assert_equal "repoglean #{version}\n", shell_output("#{bin}/repoglean --version")
  end
end
