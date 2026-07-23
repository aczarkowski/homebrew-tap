# frozen_string_literal: true

require "json"
require "minitest/autorun"
require "tmpdir"
require "repoglean_formula"

class RepoGleanFormulaTest < Minitest::Test
  SHA256 = {
    "osx-arm64" => "2" * 64,
    "osx-x64" => "3" * 64,
    "linux-arm64" => "4" * 64,
    "linux-x64" => "5" * 64,
  }.freeze

  def release_payload(tag: "v2.0.0", draft: false, prerelease: false)
    assets = RepoGleanFormula::RIDS.flat_map do |rid|
      archive = "repoglean-#{rid}.tar.gz"
      [
        { "name" => archive, "browser_download_url" => "https://example.test/#{archive}" },
        {
          "name" => "#{archive}.sha256",
          "browser_download_url" => "https://example.test/#{archive}.sha256",
        },
      ]
    end

    {
      "tag_name" => tag,
      "draft" => draft,
      "prerelease" => prerelease,
      "assets" => assets,
    }
  end

  def checksum_loader(overrides = {})
    lambda do |url|
      name = File.basename(URI(url).path)
      overrides.fetch(name) do
        rid = name.delete_prefix("repoglean-").delete_suffix(".tar.gz.sha256")
        "#{SHA256.fetch(rid)}  #{name.delete_suffix(".sha256")}\n"
      end
    end
  end

  def test_renders_all_platforms_and_formula_contract
    release = RepoGleanFormula.parse_release(
      release_payload,
      checksum_loader: checksum_loader,
    )
    rendered = RepoGleanFormula.render(release)

    assert_equal "2.0.0", release.version
    RepoGleanFormula::RIDS.each do |rid|
      assert_includes rendered, "https://example.test/repoglean-#{rid}.tar.gz"
      assert_includes rendered, SHA256.fetch(rid)
    end
    assert_includes rendered, 'depends_on "git"'
    assert_includes rendered, "strategy :github_latest"
    assert_includes rendered, 'assert_equal "repoglean #{version}\\n"'

    Dir.mktmpdir do |directory|
      path = File.join(directory, "repoglean.rb")
      File.write(path, rendered)
      assert_equal "2.0.0", RepoGleanFormula.current_version(path)
    end
  end

  def assert_release_error(message, payload: release_payload, loader: checksum_loader)
    error = assert_raises(ArgumentError) do
      RepoGleanFormula.parse_release(payload, checksum_loader: loader)
    end
    assert_equal message, error.message
  end

  def test_rejects_malformed_tag
    assert_release_error(
      "release tag must be v<major>.<minor>.<patch>",
      payload: release_payload(tag: "release-2.0.0"),
    )
  end

  def test_rejects_draft_and_prerelease
    assert_release_error("release is not stable", payload: release_payload(draft: true))
    assert_release_error(
      "release is not stable",
      payload: release_payload(prerelease: true),
    )
  end

  def test_rejects_each_missing_asset
    release_payload.fetch("assets").each do |asset|
      payload = release_payload
      payload["assets"].reject! do |candidate|
        candidate.fetch("name") == asset.fetch("name")
      end
      assert_release_error("missing asset: #{asset.fetch("name")}", payload: payload)
    end
  end

  def test_rejects_malformed_checksum
    name = "repoglean-osx-arm64.tar.gz.sha256"
    assert_release_error(
      "invalid checksum: #{name}",
      loader: checksum_loader(name => "not-a-checksum\n"),
    )
  end
end
