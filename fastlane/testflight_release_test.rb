require "minitest/autorun"
require "tmpdir"
require_relative "testflight_release"

class TestFlightReleaseTest < Minitest::Test
  Release = WhoReadsTestFlight

  class FakeApple
    attr_accessor :records, :available
    def initialize(records = [], available = true)
      @records, @available = records, available
    end
    def validate_app! = true
    def builds = records
    def ready?(_build) = available
  end

  class StateApple < Release::Apple
    attr_accessor :state, :linked
    def initialize(state, linked)
      @state, @linked = state, linked
    end
    def get(*) = { "data" => { "attributes" => { "internalBuildState" => state } } }
    def list(*) = linked ? [{ "id" => "build" }] : []
  end

  def setup
    @environment = ENV.to_h
    ENV.update("GITHUB_REF" => "refs/heads/main", "GITHUB_SHA" => "a" * 40,
      "GITHUB_RUN_ID" => "123", "GITHUB_REPOSITORY" => "WhoReads-umc-9th/whoreads-frontend")
    @original = Dir.pwd
    @directory = Dir.mktmpdir
    Dir.chdir(@directory)
    File.write("pubspec.yaml", "version: 1.0.3+4\n")
  end

  def teardown
    Dir.chdir(@original)
    FileUtils.remove_entry(@directory)
    ENV.replace(@environment)
  end

  def record(version = "1.0.3", number = "4")
    { "id" => "uploaded-build", "app_version" => version, "build_number" => number }
  end

  def artifact(apple = FakeApple.new)
    plan = Release.plan(apple: apple)
    FileUtils.mkdir_p(".release/ios-artifacts")
    File.write(".release/ios-artifacts/whoreads.ipa", "audited fixture")
    manifest = plan.merge("sha256" => Digest::SHA256.hexdigest("audited fixture"), "internal_only" => true)
    Release.write_json(".release/ios-artifacts/manifest.json", manifest)
    [plan, manifest]
  end

  def test_both_numbers_increase_against_the_uploaded_version
    assert_equal ["1.0.4", "5"], Release.next_version("1.0.3+4", [record])
    assert_equal ["1.1.1", "51"], Release.next_version("1.0.3+4", [record("1.1.0", "50")])
    assert_equal ["2.0.0", "90"], Release.next_version("2.0.0+90", [record])
  end

  def test_rerun_reuses_its_original_plan
    apple = FakeApple.new([record])
    first = Release.plan(apple: apple)
    apple.records << record("1.0.4", "5")
    assert_equal first, Release.plan(apple: apple)
    ENV["GITHUB_SHA"] = "b" * 40
    assert_raises(RuntimeError) { Release.load_plan }
  end

  def test_other_branches_cannot_plan_or_publish
    ENV["GITHUB_REF"] = "refs/heads/feature"
    assert_raises(RuntimeError) { Release.plan(apple: FakeApple.new) }
  end

  def test_changed_artifact_is_rejected_before_upload
    artifact
    File.write(".release/ios-artifacts/whoreads.ipa", "changed")
    assert_raises(RuntimeError) { Release.publish(apple: FakeApple.new) }
  end

  def test_existing_build_from_another_upload_is_not_claimed
    plan, = artifact
    apple = FakeApple.new([record(plan["version_name"], plan["build_number"])])
    assert_raises(RuntimeError) { Release.publish(apple: apple) }
  end

  def test_confirmed_own_upload_can_resume_without_another_upload
    plan, manifest = artifact
    Release.write_json(Release::RESULT, plan.merge("upload_started" => true, "ready" => false, "sha256" => manifest["sha256"]))
    apple = FakeApple.new([record(plan["version_name"], plan["build_number"])])
    assert Release.publish(apple: apple)["ready"]
  end

  def test_ambiguous_upload_is_not_retried
    plan, manifest = artifact
    Release.write_json(Release::RESULT, plan.merge("upload_started" => true, "sha256" => manifest["sha256"]))
    assert_raises(RuntimeError) { Release.publish(apple: FakeApple.new) }
  end

  def test_success_notification_requires_verified_readiness
    assert_raises(RuntimeError) do
      Release.notify(status: "success", webhook: "https://discord.com/api/webhooks/123/fixture")
    end
  end

  def test_public_export_manifest_is_rejected
    _, manifest = artifact
    manifest["internal_only"] = false
    Release.write_json(".release/ios-artifacts/manifest.json", manifest)
    assert_raises(RuntimeError) { Release.publish(apple: FakeApple.new) }
  end

  def test_uploaded_or_processing_is_not_ready_for_testing
    build = { "id" => "build", "processing_state" => "PROCESSING", "audience" => "INTERNAL_ONLY" }
    apple = StateApple.new("IN_BETA_TESTING", true)
    refute apple.ready?(build)
    build["processing_state"] = "VALID"
    apple.state = "READY_FOR_BETA_TESTING"
    refute apple.ready?(build)
    apple.state = "IN_BETA_TESTING"
    apple.linked = false
    refute apple.ready?(build)
    apple.linked = true
    assert apple.ready?(build)
  end

  def test_apple_must_confirm_internal_only_audience
    apple = StateApple.new("IN_BETA_TESTING", true)
    build = { "id" => "build", "processing_state" => "VALID", "audience" => "APP_STORE_ELIGIBLE" }
    assert_raises(RuntimeError) { apple.ready?(build) }
  end
end
