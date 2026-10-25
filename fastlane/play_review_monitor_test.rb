require "minitest/autorun"
require_relative "play_review_monitor"

class PlayReviewMonitorTest < Minitest::Test
  MONITOR = WhoReadsReviewMonitor
  IN_REVIEW = "RELEASE_LIFECYCLE_STATE_IN_REVIEW"
  APPROVED = "RELEASE_LIFECYCLE_STATE_APPROVED_NOT_PUBLISHED"
  PUBLISHED = "RELEASE_LIFECYCLE_STATE_PUBLISHED"

  class Store
    attr_accessor :state, :fail_save
    attr_reader :saves

    def initialize
      @state = { "notifications" => {} }
      @saves = 0
    end

    def load = Marshal.load(Marshal.dump(state))

    def save(value)
      raise "Storage unavailable" if fail_save

      @state = Marshal.load(Marshal.dump(value))
      @saves += 1
    end
  end

  class Webhook
    attr_accessor :fail_send
    attr_reader :calls

    def initialize
      @calls = 0
    end

    def send_message
      @calls += 1
      raise IOError, "Ambiguous delivery" if fail_send

      "123456789"
    end
  end

  def setup
    @store, @webhook = Store.new, Webhook.new
    @summary = ENV.delete("GITHUB_STEP_SUMMARY")
  end

  def teardown
    ENV["GITHUB_STEP_SUMMARY"] = @summary if @summary
  end

  def release(code, lifecycle)
    { "track" => "alpha", "releaseName" => "WhoReads", "activeArtifacts" => [{ "versionCode" => code }],
      "releaseLifecycleState" => lifecycle }
  end

  def run_monitor(releases, **options)
    result = nil
    capture_io do
      result = MONITOR.run(releases: releases, store: @store, discord: @webhook, **options)
    end
    result
  end

  def test_discord_waits_for_confirmation_and_disables_mentions
    response = { "id" => "123456789", "content" => MONITOR::MESSAGE }
    request = lambda do |method, url, **options|
      assert_equal "post", method
      assert url.end_with?("?wait=true")
      assert_equal "[WhoReads] - Android 비공개 테스트 배포 완료", options.fetch(:body).fetch("content")
      assert_equal({ "parse" => [] }, options.fetch(:body).fetch("allowed_mentions"))
      response
    end
    MONITOR.stub(:request, request) do
      assert_equal "123456789", MONITOR::Discord.new("https://discord.com/api/webhooks/123/test_token").send_message
    end
  end

  def test_in_review_rejected_and_draft_do_not_notify
    [IN_REVIEW, "RELEASE_LIFECYCLE_STATE_NOT_APPROVED", "RELEASE_LIFECYCLE_STATE_DRAFT",
      "RELEASE_LIFECYCLE_STATE_NOT_SENT_FOR_REVIEW", "RELEASE_LIFECYCLE_STATE_UNSPECIFIED", "completed"].each do |state|
      assert_equal :waiting, run_monitor([release(10, state)])
    end
    assert_equal 0, @webhook.calls
    assert_equal 1, @store.saves
  end

  def test_review_approval_waits_for_publication
    assert_equal :waiting, run_monitor([release(10, APPROVED)])
    assert_equal 0, @webhook.calls
    assert_nil @store.state["notifications"]["10"]
  end

  def test_already_published_current_release_can_notify_on_first_check
    assert_equal :sent, run_monitor([release(10, PUBLISHED)])
    assert_equal "123456789", @store.state["notifications"]["10"]["message_id"]
  end

  def test_publication_and_repeated_checks_notify_only_once
    run_monitor([release(10, APPROVED)])
    3.times { run_monitor([release(10, PUBLISHED)]) }
    assert_equal 1, @webhook.calls
    assert_equal 3, @store.saves
  end

  def test_historical_approved_release_cannot_hide_new_release_in_review
    assert_equal :waiting, run_monitor([release(9, PUBLISHED), release(10, IN_REVIEW)])
    assert_equal 0, @webhook.calls
  end

  def test_older_published_release_is_ignored_if_a_newer_review_disappears
    run_monitor([release(10, IN_REVIEW)])
    run_monitor([release(9, PUBLISHED)])
    assert_equal 0, @webhook.calls
    assert_equal 10, @store.state["latest_version_code"]
  end

  def test_next_version_gets_its_own_single_notification
    run_monitor([release(10, PUBLISHED)])
    run_monitor([release(10, PUBLISHED), release(11, IN_REVIEW)])
    run_monitor([release(11, PUBLISHED)])
    run_monitor([release(11, PUBLISHED)])
    assert_equal 2, @webhook.calls
  end

  def test_check_only_never_claims_or_sends
    run_monitor([release(10, APPROVED)], check_only: true)
    assert_equal 0, @webhook.calls
    assert_equal 0, @store.saves
  end

  def test_state_must_be_persisted_before_discord_can_send
    @store.fail_save = true
    assert_raises(RuntimeError) { run_monitor([release(10, PUBLISHED)]) }
    assert_equal 0, @webhook.calls
  end

  def test_ambiguous_delivery_is_not_automatically_repeated
    @webhook.fail_send = true
    assert_raises(IOError) { run_monitor([release(10, PUBLISHED)]) }
    @webhook.fail_send = false
    assert_raises(RuntimeError) { run_monitor([release(10, PUBLISHED)]) }
    assert_equal 1, @webhook.calls
    assert_equal "sending", @store.state["notifications"]["10"]["delivery"]
  end

  def test_other_track_is_rejected
    other = release(10, PUBLISHED).merge("track" => "production")
    assert_raises(RuntimeError) { run_monitor([other]) }
    assert_equal 0, @webhook.calls
  end

  def test_historical_release_does_not_notify_when_monitoring_starts
    run_monitor([release(8, PUBLISHED)], minimum_version_code: 9)
    assert_equal 0, @webhook.calls
    assert_equal 0, @store.saves
    assert_equal :sent, run_monitor([release(9, PUBLISHED)], minimum_version_code: 9)
  end

  def test_empty_and_inactive_releases_do_not_send
    run_monitor([])
    run_monitor([release(10, PUBLISHED).merge("activeArtifacts" => [])])
    assert_equal 0, @webhook.calls
  end

  def test_invalid_webhook_does_not_include_secret_in_error
    error = assert_raises(RuntimeError) { MONITOR::Discord.new("https://example.com/secret-token") }
    refute_includes error.message, "secret-token"
  end
end
