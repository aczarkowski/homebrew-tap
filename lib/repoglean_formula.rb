# frozen_string_literal: true

require "uri"

module RepoGleanFormula
  RIDS = %w[osx-arm64 osx-x64 linux-arm64 linux-x64].freeze
  Release = Struct.new(:version, :archives, :checksums, keyword_init: true)

  module_function

  def parse_release(payload, checksum_loader:)
    if payload.fetch("draft") || payload.fetch("prerelease")
      raise ArgumentError, "release is not stable"
    end

    match = /\Av(\d+\.\d+\.\d+)\z/.match(payload.fetch("tag_name"))
    unless match
      raise ArgumentError, "release tag must be v<major>.<minor>.<patch>"
    end

    assets = payload.fetch("assets").to_h do |asset|
      [asset.fetch("name"), asset.fetch("browser_download_url")]
    end
    archives = {}
    checksums = {}

    RIDS.each do |rid|
      archive_name = "repoglean-#{rid}.tar.gz"
      checksum_name = "#{archive_name}.sha256"
      archives[rid] = assets.fetch(archive_name) do
        raise ArgumentError, "missing asset: #{archive_name}"
      end
      checksum_url = assets.fetch(checksum_name) do
        raise ArgumentError, "missing asset: #{checksum_name}"
      end
      checksum = checksum_loader.call(checksum_url).split.first
      unless /\A[0-9a-f]{64}\z/.match?(checksum)
        raise ArgumentError, "invalid checksum: #{checksum_name}"
      end

      checksums[rid] = checksum
    end

    Release.new(version: match[1], archives: archives, checksums: checksums)
  end

  def current_version(path)
    match = File.read(path).match(/^  version "([^"]+)"$/)
    raise ArgumentError, "formula version is missing" unless match

    match[1]
  end

  def render(release)
    <<~RUBY
      class RepoGlean < Formula
        desc "Safely reclaim space from regenerable Git artifacts"
        homepage "https://github.com/aczarkowski/RepoGlean"
        version "#{release.version}"
        license "MIT"

        on_macos do
          if Hardware::CPU.arm?
            url "#{release.archives.fetch("osx-arm64")}"
            sha256 "#{release.checksums.fetch("osx-arm64")}"
          else
            url "#{release.archives.fetch("osx-x64")}"
            sha256 "#{release.checksums.fetch("osx-x64")}"
          end
        end

        on_linux do
          if Hardware::CPU.arm?
            url "#{release.archives.fetch("linux-arm64")}"
            sha256 "#{release.checksums.fetch("linux-arm64")}"
          else
            url "#{release.archives.fetch("linux-x64")}"
            sha256 "#{release.checksums.fetch("linux-x64")}"
          end
        end

        livecheck do
          url :stable
          strategy :github_latest
        end

        depends_on "git"

        def install
          rid = if OS.mac?
            Hardware::CPU.arm? ? "osx-arm64" : "osx-x64"
          else
            Hardware::CPU.arm? ? "linux-arm64" : "linux-x64"
          end
          bin.install "repoglean-\#{rid}/repoglean"
        end

        test do
          assert_equal "repoglean \#{version}\\n", shell_output("\#{bin}/repoglean --version")
        end
      end
    RUBY
  end
end
