require "minitest/autorun"
require "tmpdir"
require "google/apis/androidpublisher_v3"
require_relative "play_release"

class PlayReleaseTest < Minitest::Test
  API = Google::Apis::AndroidpublisherV3
  SHA = "a" * 40

  class FakePlay
    attr_accessor :tracks, :uploaded_sha, :commit_error
    attr_reader :uploads, :commits, :deletes

    def initialize(checksum)
      @tracks = [API::Track.new(track: "alpha", releases: [API::TrackRelease.new(version_codes: [3], status: "completed")]),
                 API::Track.new(track: "beta", releases: [API::TrackRelease.new(version_codes: [4], status: "draft")])]
      @uploaded_sha = checksum
      @uploads, @commits, @deletes = 0, [], 0
    end

    def insert_edit(*) = API::AppEdit.new(id: "temporary-edit")
    def delete_edit(*) = @deletes += 1
    def list_edit_tracks(*) = API::TracksListResponse.new(tracks: tracks)
    def list_edit_bundles(*) = API::BundlesListResponse.new(bundles: [API::Bundle.new(version_code: 4)])
    def list_edit_apks(*) = API::ApksListResponse.new(apks: [])
    def validate_edit(*) = nil

    def upload_edit_bundle(*)
      @uploads += 1
      API::Bundle.new(version_code: 5, sha256: uploaded_sha)
    end

    def update_edit_track(_package, _edit, name, track)
      raise "Unexpected track mutation" unless name == "alpha"
      @tracks = tracks.reject { |item| item.track == name } + [track]
    end

    def commit_edit(*args, **options)
      @commits << options
      raise commit_error if commit_error
      API::AppEdit.new(id: "temporary-edit")
    end
  end

  def setup
    @environment = ENV.to_h
    @directory = Dir.mktmpdir("whoreads-play-test-")
    ENV.update("PLAY_AUTO_DEPLOY" => "true", "GITHUB_REF" => "refs/heads/main",
      "GITHUB_SHA" => SHA, "RELEASE_ARTIFACT_DIR" => @directory)
    File.write(File.join(@directory, "app-release.aab"), "audited test bundle")
    File.write(File.join(@directory, "app-release.apk"), "paired test apk")
    @manifest = { "package" => WhoReadsRelease::PACKAGE, "track" => "alpha", "commit" => SHA,
      "version_name" => "1.0.4", "version_code" => 5,
      "aab_sha256" => Digest::SHA256.file(File.join(@directory, "app-release.aab")).hexdigest,
      "apk_sha256" => Digest::SHA256.file(File.join(@directory, "app-release.apk")).hexdigest }
    save_manifest
    @api = FakePlay.new(@manifest.fetch("aab_sha256"))
  end

  def teardown
    ENV.replace(@environment)
    FileUtils.remove_entry(@directory)
  end

  def save_manifest
    WhoReadsRelease.write_json(File.join(@directory, "release-manifest.json"), @manifest)
  end

  def test_drafts_and_other_tracks_determine_the_next_version
    codes = WhoReadsRelease.with_edit(@api) { |id, _| WhoReadsRelease.snapshot(@api, id).first }
    assert_equal({ "version_name" => "1.0.4", "version_code" => 5 }, WhoReadsRelease.next_version("1.0.3+4", codes))
    assert_equal 1, @api.deletes
    assert_empty @api.commits
    assert_equal 0, @api.uploads
  end

  def test_explicit_pubspec_version_bump_is_preserved
    assert_equal({ "version_name" => "1.1.0", "version_code" => 50 }, WhoReadsRelease.next_version("1.1.0+50", [4, 20]))
  end

  def test_invalid_or_exhausted_versions_are_rejected
    assert_raises(RuntimeError) { WhoReadsRelease.next_version("1.0.3", [4]) }
    assert_raises(RuntimeError) { WhoReadsRelease.next_version("1.0.3+4", [2_100_000_000]) }
  end

  def test_tampered_artifact_cannot_reach_the_play_api
    File.write(File.join(@directory, "app-release.aab"), "tampered")
    assert_raises(RuntimeError) { WhoReadsRelease.publish(api: @api) }
    assert_equal 0, @api.uploads
    assert_empty @api.commits
  end

  def test_wrong_commit_or_track_is_rejected
    @manifest["commit"] = "b" * 40
    save_manifest
    assert_raises(RuntimeError) { WhoReadsRelease.verify_manifest(@directory, SHA) }
    @manifest["commit"], @manifest["track"] = SHA, "production"
    save_manifest
    assert_raises(RuntimeError) { WhoReadsRelease.verify_manifest(@directory, SHA) }
  end

  def test_non_main_and_disabled_deployments_are_rejected
    ENV["GITHUB_REF"] = "refs/heads/feature"
    assert_raises(RuntimeError) { WhoReadsRelease.publish(api: @api) }
    ENV["GITHUB_REF"], ENV["PLAY_AUTO_DEPLOY"] = "refs/heads/main", "false"
    assert_raises(RuntimeError) { WhoReadsRelease.publish(api: @api) }
    assert_equal 0, @api.uploads
  end

  def test_only_alpha_changes_and_an_existing_review_is_never_cancelled
    beta_before = @api.tracks.find { |track| track.track == "beta" }.to_h
    capture_io { WhoReadsRelease.publish(api: @api) }
    assert_equal beta_before, @api.tracks.find { |track| track.track == "beta" }.to_h
    assert_equal [{ changes_not_sent_for_review: false, changes_in_review_behavior: "ERROR_IF_IN_REVIEW" }], @api.commits
    assert_equal 0, @api.deletes
    assert File.file?(File.join(@directory, "play-result.json"))
  end

  def test_rejected_or_ambiguous_commit_is_not_retried
    @api.commit_error = IOError.new("simulated ambiguous commit")
    capture_io { assert_raises(IOError) { WhoReadsRelease.publish(api: @api) } }
    assert_equal 1, @api.commits.length
    assert_equal 1, @api.uploads
    assert_equal 1, @api.deletes
    refute File.exist?(File.join(@directory, "play-result.json"))
  end

  def test_an_already_recorded_release_is_read_only
    @api.tracks.first.releases = [API::TrackRelease.new(version_codes: [5], status: "completed", name: "1.0.4 (#{SHA[0, 12]})")]
    result = nil
    capture_io { result = WhoReadsRelease.publish(api: @api) }
    assert_equal "already_recorded_on_alpha", result["status"]
    assert_equal 0, @api.uploads
    assert_empty @api.commits
  end

  def test_a_code_used_by_another_release_is_not_uploaded_again
    @manifest["version_code"] = 4
    save_manifest
    assert_raises(RuntimeError) { WhoReadsRelease.publish(api: @api) }
    assert_equal 0, @api.uploads
  end

  def test_missing_alpha_track_does_not_create_one
    @api.tracks.reject! { |track| track.track == "alpha" }
    assert_raises(RuntimeError) { WhoReadsRelease.publish(api: @api) }
    assert_equal 0, @api.uploads
  end

  def test_google_checksum_mismatch_prevents_commit
    @api.uploaded_sha = "wrong"
    assert_raises(RuntimeError) { WhoReadsRelease.publish(api: @api) }
    assert_empty @api.commits
  end

  def test_the_locked_client_supports_review_protection
    parameters = API::AndroidPublisherService.instance_method(:commit_edit).parameters
    assert_includes parameters, [:key, :changes_in_review_behavior]
  end
end
