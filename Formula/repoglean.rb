class Repoglean < Formula
  desc "Safely reclaim space from regenerable Git artifacts"
  homepage "https://github.com/aczarkowski/RepoGlean"
  version "2.0.0"
  license "MIT"

  livecheck do
    url :stable
    strategy :github_latest
  end

  uses_from_macos "git"

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/aczarkowski/RepoGlean/releases/download/v2.0.0/repoglean-osx-arm64.tar.gz"
      sha256 "2c5d0ef69bad09bc1283b2867f2bd22d955f8970990ee71e92f0a72464733603"
    else
      url "https://github.com/aczarkowski/RepoGlean/releases/download/v2.0.0/repoglean-osx-x64.tar.gz"
      sha256 "d58f08fb7b00f2acf0dcbdca6af8334f8ea6d9d6a44a6876dd4243df497bf900"
    end
  end

  on_linux do
    if Hardware::CPU.arm?
      url "https://github.com/aczarkowski/RepoGlean/releases/download/v2.0.0/repoglean-linux-arm64.tar.gz"
      sha256 "b52b95dcb2b24d99862fd82deb132144a18b51b9fe2e2344aa9b7b9d7695cc20"
    else
      url "https://github.com/aczarkowski/RepoGlean/releases/download/v2.0.0/repoglean-linux-x64.tar.gz"
      sha256 "3731f411e7227b092d0098e1cb89de08208096bd3b95b774a389e2a2fd9aba96"
    end
  end

  def install
    rid = if OS.mac?
      Hardware::CPU.arm? ? "osx-arm64" : "osx-x64"
    else
      Hardware::CPU.arm? ? "linux-arm64" : "linux-x64"
    end
    bin.install "repoglean-#{rid}/repoglean"
  end

  test do
    assert_equal "repoglean #{version}\n", shell_output("#{bin}/repoglean --version")
  end
end
