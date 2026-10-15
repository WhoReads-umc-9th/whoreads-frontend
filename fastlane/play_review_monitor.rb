require "base64"
require "json"
require "net/http"
require "time"
require "uri"
require_relative "play_release"

module WhoReadsReviewMonitor
  MESSAGE = "[WhoReads] - 심사 완료".freeze
  APPROVED = %w[
    RELEASE_LIFECYCLE_STATE_APPROVED_NOT_PUBLISHED
    RELEASE_LIFECYCLE_STATE_PUBLISHED
  ].freeze
  STATE_BRANCH = "codex/play-review-notifications".freeze
  STATE_PATH = "state.json".freeze

  class HttpError < StandardError
    attr_reader :status

    def initialize(host, status)
      @status = status
      super("#{host} returned HTTP #{status}; response and credentials omitted")
    end
  end

  def self.request(method, url, token: nil, body: nil)
    uri = URI(url)
    raise "Only HTTPS requests are allowed" unless uri.scheme == "https"

    request = Net::HTTP.const_get(method.capitalize).new(uri)
    request["User-Agent"] = "WhoReads Play review monitor"
    request["Accept"] = "application/json"
    request["Authorization"] = "Bearer #{token}" if token
    if body
      request["Content-Type"] = "application/json"
      request.body = JSON.generate(body)
    end
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true,
      open_timeout: 20, read_timeout: 30, write_timeout: 30) { |http| http.request(request) }
    raise HttpError.new(uri.host, response.code.to_i) unless response.is_a?(Net::HTTPSuccess)

    response.body.to_s.empty? ? {} : JSON.parse(response.body)
  end

  def self.releases
    # The editable track status "completed" is not a review approval signal.
    # This read-only endpoint exposes the actual release lifecycle instead.
    authorization = WhoReadsRelease.service.authorization
    token = authorization.fetch_access_token!.fetch("access_token")
    response = request("get", "https://androidpublisher.googleapis.com/androidpublisher/v3/" \
      "applications/#{WhoReadsRelease::PACKAGE}/tracks/#{WhoReadsRelease::TRACK}/releases", token: token)
    releases = response.fetch("releases", [])
    raise "Invalid Play releases response" unless releases.is_a?(Array)

    releases
  end

  class GitHubState
    def initialize(repository:, token:)
      raise "Invalid GitHub repository" unless /\A[\w.-]+\/[\w.-]+\z/.match?(repository)

      @base = "https://api.github.com/repos/#{repository}"
      @token = token
    end

    def call(method, path, body = nil)
      WhoReadsReviewMonitor.request(method, "#{@base}/#{path}", token: @token, body: body)
    end

    def load
      begin
        file = call("get", "contents/#{STATE_PATH}?ref=#{STATE_BRANCH}")
      rescue HttpError => error
        raise unless error.status == 404

        @sha = nil
        return { "schema" => 1, "package" => WhoReadsRelease::PACKAGE,
          "track" => WhoReadsRelease::TRACK, "notifications" => {} }
      end
      @sha = file.fetch("sha")
      state = JSON.parse(Base64.decode64(file.fetch("content")))
      unless state["schema"] == 1 && state["package"] == WhoReadsRelease::PACKAGE &&
          state["track"] == WhoReadsRelease::TRACK && state["notifications"].is_a?(Hash)
        raise "Invalid notification state; refusing to risk duplicate delivery"
      end
      state
    end

    def save(state)
      content = JSON.pretty_generate(state) + "\n"
      if @sha
        result = call("put", "contents/#{STATE_PATH}", {
          "message" => "Record Play review notification [skip ci]", "branch" => STATE_BRANCH,
          "sha" => @sha, "content" => Base64.strict_encode64(content)
        })
        @sha = result.fetch("content").fetch("sha")
      else
        # An orphan branch stores non-secret delivery receipts without changing main
        # or starting the mobile release workflow. Never overwrite an existing ref.
        blob = call("post", "git/blobs", { "encoding" => "utf-8", "content" => content })
        tree = call("post", "git/trees", { "tree" => [
          { "path" => STATE_PATH, "mode" => "100644", "type" => "blob", "sha" => blob.fetch("sha") }
        ] })
        commit = call("post", "git/commits", {
          "message" => "Initialize Play review notification receipts [skip ci]",
          "tree" => tree.fetch("sha"), "parents" => []
        })
        call("post", "git/refs", { "ref" => "refs/heads/#{STATE_BRANCH}", "sha" => commit.fetch("sha") })
        @sha = blob.fetch("sha")
      end
    end
  end

  class Discord
    def initialize(url)
      # Never interpolate this credential into logs, exceptions, or a shell command.
      unless %r{\Ahttps://discord\.com/api/webhooks/\d+/[\w-]+\z}.match?(url)
        raise "DISCORD_WEBHOOK_URL is not a Discord webhook URL"
      end
      @url = "#{url}?wait=true"
    end

    def send_message
      response = WhoReadsReviewMonitor.request("post", @url,
        body: { "content" => MESSAGE, "allowed_mentions" => { "parse" => [] } })
      unless /\A\d+\z/.match?(response["id"].to_s) && response["content"] == MESSAGE
        raise "Discord delivery was not confirmed; reconcile before resending"
      end
      response.fetch("id")
    end
  end

  def self.run(releases:, store:, discord:, check_only: false)
    candidates = releases.filter_map do |release|
      raise "Unexpected Play track in review response" unless release["track"] == WhoReadsRelease::TRACK

      codes = release.fetch("activeArtifacts", []).map { |artifact| Integer(artifact.fetch("versionCode")) }.sort
      raise "Invalid Play version code" unless codes.all?(&:positive?)
      next if codes.empty?

      [codes.max, codes, release]
    end
    latest = candidates.max_by(&:first)
    return report("No active Alpha release was returned; no notification sent") unless latest

    code, codes, release = latest
    lifecycle = release.fetch("releaseLifecycleState")
    report("Alpha versionCode #{code}: #{lifecycle}")
    return report("Check only: no notification sent or recorded") if check_only

    state = store.load
    seen_code = state.fetch("latest_version_code", 0)
    return report("Ignoring older versionCode #{code}; monitoring #{seen_code}") if code < seen_code

    state["latest_version_code"] = code
    unless APPROVED.include?(lifecycle)
      store.save(state) if code > seen_code
      return :waiting
    end
    key = code.to_s
    prior = state.fetch("notifications")[key]
    if prior
      return report("Review completion for versionCode #{code} was already notified") if prior["delivery"] == "sent"

      raise "Delivery for versionCode #{code} needs reconciliation; refusing a duplicate send"
    end
    receipt = {
      "delivery" => "sending", "version_codes" => codes, "lifecycle" => lifecycle,
      "claimed_at" => Time.now.utc.iso8601
    }
    state["notifications"][key] = receipt
    # Claim persistently before posting. An ambiguous HTTP timeout or runner crash
    # must never turn the next scheduled check into a second Discord message.
    store.save(state)
    message_id = discord.send_message
    puts "Discord confirmed message #{message_id}"
    receipt.merge!("delivery" => "sent", "message_id" => message_id, "sent_at" => Time.now.utc.iso8601)
    store.save(state)
    report("Sent: #{MESSAGE} (versionCode #{code})")
    :sent
  end

  def self.report(message)
    puts message
    File.open(ENV["GITHUB_STEP_SUMMARY"], "a") { |file| file.puts(message + "\n") } if ENV["GITHUB_STEP_SUMMARY"]
    message
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    check_only = ENV.fetch("MONITOR_CHECK_ONLY", "false") == "true"
    WhoReadsReviewMonitor.run(releases: WhoReadsReviewMonitor.releases,
      store: WhoReadsReviewMonitor::GitHubState.new(repository: ENV.fetch("GITHUB_REPOSITORY"), token: ENV.fetch("GH_TOKEN")),
      discord: check_only ? nil : WhoReadsReviewMonitor::Discord.new(ENV.fetch("DISCORD_WEBHOOK_URL")),
      check_only: check_only)
  rescue StandardError => error
    # API response bodies and exception URLs can contain credentials.
    warn "Play review monitor failed (#{error.class})."
    warn error.message if error.is_a?(WhoReadsReviewMonitor::HttpError) || error.class == RuntimeError
    exit 1
  end
end
