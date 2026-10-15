require "digest"
require "fileutils"
require "json"
require "open3"
require "yaml"

module WhoReadsRelease
  PACKAGE = "com.whoreads.mobile".freeze
  TRACK = "alpha".freeze
  ROOT = File.expand_path("..", __dir__).freeze
  MAX_VERSION_CODE = 2_100_000_000

  def self.next_version(version, used_codes)
    match = /\A(\d+)\.(\d+)\.(\d+)\+(\d+)\z/.match(version)
    raise "pubspec version must have the form 1.2.3+4" unless match

    major, minor, patch, baseline = match.captures.map(&:to_i)
    code = [baseline, (used_codes.map { |value| Integer(value) }.max || 0) + 1].max
    raise "Android versionCode limit exceeded" unless code.between?(1, MAX_VERSION_CODE)

    # Preserve an explicit pubspec bump; otherwise advance both the patch and code.
    { "version_name" => "#{major}.#{minor}.#{patch + code - baseline}", "version_code" => code }
  end

  def self.service
    require "google/apis/androidpublisher_v3"
    require "googleauth"
    require "stringio"
    data = ENV.fetch("PLAY_SERVICE_ACCOUNT_JSON")
    credentials = JSON.parse(data)
    unless credentials["type"] == "service_account" && credentials["client_email"] && credentials["private_key"]
      raise "PLAY_SERVICE_ACCOUNT_JSON must contain a Play deployment service account"
    end

    api = Google::Apis::AndroidpublisherV3::AndroidPublisherService.new
    api.authorization = Google::Auth::ServiceAccountCredentials.make_creds(
      json_key_io: StringIO.new(data), scope: "https://www.googleapis.com/auth/androidpublisher"
    )
    api.client_options.application_name = "WhoReads closed-test deployment"
    # A timeout during a mutation must be reconciled, never silently retried.
    api.request_options.retries = 0
    api.client_options.open_timeout_sec = 30
    api.client_options.read_timeout_sec = 300
    api.client_options.send_timeout_sec = 300
    api
  end

  def self.with_edit(api)
    edit = api.insert_edit(PACKAGE)
    committed = false
    begin
      result = yield edit.id, -> { committed = true }
      result
    ensure
      unless committed
        begin
          api.delete_edit(PACKAGE, edit.id)
        rescue StandardError
          warn "Temporary Play edit could not be cleaned up; no retry was attempted."
        end
      end
    end
  end

  def self.snapshot(api, edit_id)
    tracks = api.list_edit_tracks(PACKAGE, edit_id).tracks || []
    target = tracks.find { |track| track.track == TRACK }
    raise "Existing Alpha closed-test track was not found; refusing to create a track" unless target

    codes = (api.list_edit_bundles(PACKAGE, edit_id).bundles || []).map(&:version_code)
    codes.concat((api.list_edit_apks(PACKAGE, edit_id).apks || []).map(&:version_code))
    codes.concat(tracks.flat_map { |track| (track.releases || []).flat_map { |release| release.version_codes || [] } })
    [codes.map(&:to_i), target, tracks]
  end

  def self.assert_closed_test_scope!(api, edit_id, tracks)
    # Play commit can submit pre-existing Console changes as well as this edit.
    # This app currently uses Alpha only. Reject other releases or country drafts
    # before uploading, even when our code never explicitly updates those tracks.
    tracks.reject { |track| track.track == TRACK }.each do |track|
      unless (track.releases || []).empty?
        raise "Non-Alpha track #{track.track} has releases; closed-test-only deployment is blocked"
      end
      next if track.track == "internal"

      availability = api.get_edit_countryavailability(PACKAGE, edit_id, track.track)
      unless (availability.countries || []).empty?
        raise "Non-Alpha track #{track.track} has country settings; clear unrelated Console changes before deploying"
      end
    end
  end

  def self.write_json(path, data)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, JSON.pretty_generate(data) + "\n")
  end

  def self.prepare
    enabled = ENV.fetch("PLAY_AUTO_DEPLOY", "false") == "true"
    used_codes = []
    if enabled
      api = service
      used_codes = with_edit(api) do |id, _|
        codes, _, tracks = snapshot(api, id)
        assert_closed_test_scope!(api, id, tracks)
        codes
      end
    end
    version = YAML.safe_load_file(File.join(ROOT, "pubspec.yaml")).fetch("version")
    plan = next_version(version, used_codes).merge(
      "package" => PACKAGE, "track" => TRACK, "commit" => ENV.fetch("GITHUB_SHA"),
      "deploy" => enabled, "previous_max_version_code" => used_codes.max || 0
    )
    write_json(File.join(ROOT, ".release/plan.json"), plan)
    if ENV["GITHUB_OUTPUT"]
      File.open(ENV["GITHUB_OUTPUT"], "a") do |file|
        %w[version_name version_code deploy].each { |key| file.puts "#{key}=#{plan.fetch(key)}" }
      end
    end
    puts JSON.pretty_generate(plan)
    unless enabled
      puts "Play upload is disabled. Configure PLAY_SERVICE_ACCOUNT_JSON and set PLAY_AUTO_DEPLOY=true."
    end
    plan
  end

  def self.manifest(directory, expected_version, expected_code, sha, aapt2)
    aab = File.join(directory, "app-release.aab")
    apk = File.join(directory, "app-release.apk")
    badging, status = Open3.capture2e(aapt2, "dump", "badging", apk)
    raise "Could not inspect the paired release APK" unless status.success?

    metadata = /package: name='([^']+)' versionCode='(\d+)' versionName='([^']+)'/.match(badging)
    unless metadata && metadata[1] == PACKAGE && metadata[2].to_i == Integer(expected_code) && metadata[3] == expected_version
      raise "Built APK package/version does not match the release plan"
    end
    raise "Invalid release commit" unless /\A[0-9a-f]{40}\z/.match?(sha)

    result = {
      "package" => PACKAGE, "track" => TRACK, "commit" => sha,
      "version_name" => expected_version, "version_code" => Integer(expected_code),
      "aab_sha256" => Digest::SHA256.file(aab).hexdigest,
      "apk_sha256" => Digest::SHA256.file(apk).hexdigest
    }
    write_json(File.join(directory, "release-manifest.json"), result)
    result
  end

  def self.verify_manifest(directory, sha)
    manifest = JSON.parse(File.read(File.join(directory, "release-manifest.json")))
    unless manifest["package"] == PACKAGE && manifest["track"] == TRACK && manifest["commit"] == sha
      raise "Release provenance does not match this main commit and Alpha track"
    end
    %w[aab apk].each do |extension|
      file = File.join(directory, "app-release.#{extension}")
      unless Digest::SHA256.file(file).hexdigest == manifest.fetch("#{extension}_sha256")
        raise "Release #{extension.upcase} checksum does not match the audited artifact"
      end
    end
    raise "Invalid release versionCode" unless manifest.fetch("version_code").is_a?(Integer) &&
      manifest["version_code"].between?(1, MAX_VERSION_CODE)

    manifest
  end

  def self.publish(api: nil)
    raise "Automatic Play deployment is disabled" unless ENV.fetch("PLAY_AUTO_DEPLOY", "false") == "true"
    raise "Only main may deploy" unless ENV.fetch("GITHUB_REF") == "refs/heads/main"

    directory = ENV.fetch("RELEASE_ARTIFACT_DIR")
    manifest = verify_manifest(directory, ENV.fetch("GITHUB_SHA"))
    api ||= service
    with_edit(api) do |id, committed|
      codes, target, tracks_before = snapshot(api, id)
      assert_closed_test_scope!(api, id, tracks_before)
      code = manifest.fetch("version_code")
      # A rerun after a successful or ambiguously timed-out commit is read-only.
      matching = (target.releases || []).find do |release|
        (release.version_codes || []).map(&:to_i).include?(code)
      end
      if matching && matching.name == "#{manifest.fetch('version_name')} (#{manifest.fetch('commit')[0, 12]})" &&
          matching.status == "completed"
        puts "This exact release is already recorded on Alpha; upload was skipped."
        result = manifest.merge("status" => "already_recorded_on_alpha")
        write_json(File.join(directory, "play-result.json"), result)
        next result
      end
      raise "Version code is already used on Play; create a new build" if codes.include?(code)
      raise "A newer version is already on Play; refusing an older build" if (codes.max || 0) >= code

      bundle = api.upload_edit_bundle(PACKAGE, id,
        upload_source: File.join(directory, "app-release.aab"), content_type: "application/octet-stream")
      raise "Play reported a different AAB version code" unless bundle.version_code.to_i == code
      raise "Play reported a different AAB checksum" unless bundle.sha256 == manifest.fetch("aab_sha256")

      release = Google::Apis::AndroidpublisherV3::TrackRelease.new(
        name: "#{manifest.fetch('version_name')} (#{manifest.fetch('commit')[0, 12]})",
        version_codes: [code], status: "completed",
        release_notes: [Google::Apis::AndroidpublisherV3::LocalizedText.new(
          language: "ko-KR", text: File.read(File.join(ROOT, "fastlane/release-notes.ko.txt")).strip
        )]
      )
      api.update_edit_track(PACKAGE, id, TRACK,
        Google::Apis::AndroidpublisherV3::Track.new(track: TRACK, releases: [release]))
      tracks_after = api.list_edit_tracks(PACKAGE, id).tracks || []
      other_tracks = ->(tracks) { tracks.reject { |track| track.track == TRACK }.map(&:to_h).sort_by { |track| track[:track] } }
      raise "Another Play track changed during this edit" unless other_tracks.call(tracks_before) == other_tracks.call(tracks_after)

      api.validate_edit(PACKAGE, id)
      # Never cancel an existing review or silently fall back to an unsubmitted edit.
      api.commit_edit(PACKAGE, id, changes_not_sent_for_review: false,
        changes_in_review_behavior: "ERROR_IF_IN_REVIEW")
      committed.call
      result = manifest.merge("status" => "submitted_to_play; review_and_tester_availability_not_confirmed")
      write_json(File.join(directory, "play-result.json"), result)
      puts JSON.pretty_generate(result)
      result
    end
  end
end

if $PROGRAM_NAME == __FILE__
  case ARGV.shift
  when "manifest"
    puts JSON.pretty_generate(WhoReadsRelease.manifest(*ARGV))
  when "verify"
    puts JSON.pretty_generate(WhoReadsRelease.verify_manifest(*ARGV))
  else
    abort "Usage: play_release.rb manifest DIR VERSION CODE SHA AAPT2 | verify DIR SHA"
  end
end
