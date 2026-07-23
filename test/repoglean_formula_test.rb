# frozen_string_literal: true

require "json"
require "minitest/autorun"
require "open3"
require "tmpdir"
require "webrick"
require "yaml"
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
    assert_includes rendered, "class Repoglean < Formula"
    RepoGleanFormula::RIDS.each do |rid|
      assert_includes rendered, "https://example.test/repoglean-#{rid}.tar.gz"
      assert_includes rendered, SHA256.fetch(rid)
    end
    assert_includes rendered, 'uses_from_macos "git"'
    refute_includes rendered, 'depends_on "git"'
    assert_includes rendered, "strategy :github_latest"
    assert_includes rendered, 'assert_equal "repoglean #{version}\\n"'
    assert_includes rendered, 'bin.install "repoglean"'
    refute_includes rendered, 'bin.install "repoglean-#{rid}/repoglean"'
    assert_operator rendered.index("livecheck do"), :<, rendered.index("on_macos do")
    assert_operator rendered.index('uses_from_macos "git"'), :<, rendered.index("on_macos do")

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

  def test_cli_updates_then_reports_current
    Dir.mktmpdir do |directory|
      release_path = File.join(directory, "release.json")
      formula_path = File.join(directory, "repoglean.rb")
      File.write(release_path, JSON.generate(release_payload))
      RepoGleanFormula::RIDS.each do |rid|
        name = "repoglean-#{rid}.tar.gz.sha256"
        File.write(
          File.join(directory, name),
          "#{SHA256.fetch(rid)}  #{name.delete_suffix(".sha256")}\n",
        )
      end

      environment = {
        "REPOGLEAN_RELEASE_JSON" => release_path,
        "REPOGLEAN_CHECKSUM_DIRECTORY" => directory,
        "REPOGLEAN_FORMULA_PATH" => formula_path,
      }
      command = [File.expand_path("../script/update-repoglean", __dir__)]

    stdout, stderr, status = Open3.capture3(environment, *command)
    assert status.success?, stderr
    assert_equal "updated repoglean to 2.0.0\n", stdout
    assert_equal 0o644, File.stat(formula_path).mode & 0o777

      first_bytes = File.binread(formula_path)
      stdout, stderr, status = Open3.capture3(environment, *command)
      assert status.success?, stderr
      assert_equal "repoglean 2.0.0 is current\n", stdout
      assert_equal first_bytes, File.binread(formula_path)
    end
  end

  def test_cli_follows_checksum_asset_redirects
    logger = WEBrick::Log.new(File::NULL, WEBrick::Log::FATAL)
    server = WEBrick::HTTPServer.new(
      Port: 0,
      BindAddress: "127.0.0.1",
      Logger: logger,
      AccessLog: [],
    )
    port = server.listeners.fetch(0).addr[1]
    server.mount_proc("/redirect") do |request, response|
      response.status = 302
      response["Location"] = "http://127.0.0.1:#{port}/checksum?#{request.query_string}"
    end
    server.mount_proc("/checksum") do |request, response|
      unless request["authorization"] == "Bearer test-token"
        response.status = 401
        next
      end

      rid = request.query.fetch("rid")
      name = "repoglean-#{rid}.tar.gz"
      response.body = "#{SHA256.fetch(rid)}  #{name}\n"
    end
    thread = Thread.new { server.start }

    Dir.mktmpdir do |directory|
      payload = release_payload
      payload.fetch("assets").each do |asset|
        next unless asset.fetch("name").end_with?(".sha256")

        rid = asset.fetch("name")
          .delete_prefix("repoglean-")
          .delete_suffix(".tar.gz.sha256")
        asset["browser_download_url"] =
          "http://127.0.0.1:#{port}/redirect?rid=#{rid}"
      end
      release_path = File.join(directory, "release.json")
      formula_path = File.join(directory, "repoglean.rb")
      File.write(release_path, JSON.generate(payload))

      stdout, stderr, status = Open3.capture3(
        {
          "REPOGLEAN_RELEASE_JSON" => release_path,
          "REPOGLEAN_FORMULA_PATH" => formula_path,
          "GITHUB_TOKEN" => "test-token",
        },
        File.expand_path("../script/update-repoglean", __dir__),
      )

      assert status.success?, "#{stdout}#{stderr}"
      assert_equal "updated repoglean to 2.0.0\n", stdout
    end
  ensure
    server&.shutdown
    thread&.join
  end

  def test_update_workflow_is_scheduled_scoped_and_reviewed
    workflow_path = File.expand_path(
      "../.github/workflows/update-repoglean.yml",
      __dir__,
    )
    source = File.read(workflow_path)
    workflow = YAML.safe_load(source)
    triggers = workflow["on"] || workflow.fetch(true)

    assert_equal(
      "17 6 * * *",
      triggers.fetch("schedule").fetch(0).fetch("cron"),
    )
    assert triggers.key?("workflow_dispatch")
    assert_equal "write", workflow.fetch("permissions").fetch("contents")
    assert_equal(
      "write",
      workflow.fetch("permissions").fetch("pull-requests"),
    )
    refute_includes source, "secrets."
    refute_includes source, "push origin master"
    [
      "test/repoglean_formula_test.rb",
      "script/update-repoglean",
      "GITHUB_TOKEN: ${{ github.token }}",
      "brew style",
      "brew audit --strict --online",
      "brew livecheck",
      "gh pr create",
    ].each { |command| assert_includes source, command }
  end
end
