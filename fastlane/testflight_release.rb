require "base64"
require "digest"
require "fileutils"
require "json"
require "jwt"
require "net/http"
require "open3"
require "openssl"
require "time"
require "uri"

module WhoReadsTestFlight
  APP_ID = "6820093454".freeze
  BUNDLE_ID = "com.example.whoreads".freeze
  TEAM_ID = "H78DY23Q9M".freeze
  GROUP_ID = "0b9dd172-eeb0-43f9-938a-11a4dede87b0".freeze
  GROUP_NAME = "WhoReads Internal".freeze
  PLAN = ".release/ios-plan.json".freeze
  RESULT = ".release/ios-result.json".freeze
  MESSAGE = "[WhoReads] - ios TestFlight 완료".freeze

  def self.guard_main!
    raise "Only main can deploy to TestFlight" unless ENV["GITHUB_REF"] == "refs/heads/main"
    raise "Invalid source commit" unless /\A[0-9a-f]{40}\z/.match?(ENV["GITHUB_SHA"].to_s)
  end

  def self.write_json(path, data)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, JSON.pretty_generate(data) + "\n")
  end

  def self.load_plan
    guard_main!
    plan = JSON.parse(File.read(PLAN))
    unless plan.values_at("app_id", "bundle_id", "team_id", "group_id", "commit", "run_id") ==
        [APP_ID, BUNDLE_ID, TEAM_ID, GROUP_ID, ENV.fetch("GITHUB_SHA"), ENV.fetch("GITHUB_RUN_ID")]
      raise "Release plan does not match this app, commit, or workflow run"
    end
    version_parts(plan.fetch("version_name"))
    raise "Invalid build number" unless /\A[1-9]\d*\z/.match?(plan.fetch("build_number").to_s)
    plan
  end

  def self.version_parts(version)
    raise "Expected a three-part app version" unless /\A\d+\.\d+\.\d+\z/.match?(version.to_s)
    version.split(".").map(&:to_i)
  end

  def self.next_version(pubspec_version, builds)
    current, number = pubspec_version.split("+", 2)
    current_parts = version_parts(current)
    highest = builds.map { |build| version_parts(build.fetch("app_version")) }.max
    if highest.nil? || (current_parts <=> highest) == 1
      version = current
    else
      version = [highest[0], highest[1], highest[2] + 1].join(".")
    end
    numbers = builds.map { |build| Integer(build.fetch("build_number"), 10) }
    [version, [Integer(number || "1", 10), (numbers.max || 0) + 1].max.to_s]
  end

  class Apple
    BASE = "https://api.appstoreconnect.apple.com".freeze

    def token
      key = OpenSSL::PKey.read(Base64.strict_decode64(ENV.fetch("ASC_PRIVATE_KEY_BASE64")))
      JWT.encode({ iss: ENV.fetch("ASC_ISSUER_ID"), iat: Time.now.to_i - 10,
        exp: Time.now.to_i + 600, aud: "appstoreconnect-v1" }, key, "ES256",
        { kid: ENV.fetch("ASC_KEY_ID"), typ: "JWT" })
    end

    # Deliberately read-only: this client cannot submit App Store reviews/releases,
    # modify availability, change testers, or create credentials.
    def get(path, query = {})
      raise "Unexpected Apple API path" unless path.start_with?("/v1/")
      uri = URI(BASE + path)
      uri.query = URI.encode_www_form(query) unless query.empty?
      request = Net::HTTP::Get.new(uri)
      request["Authorization"] = "Bearer #{token}"
      request["Accept"] = "application/json"
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true,
        open_timeout: 20, read_timeout: 60) { |http| http.request(request) }
      raise "Apple API returned HTTP #{response.code}; credentials and response omitted" unless response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body)
    end

    def list(path, query = {})
      items = []
      100.times do
        page = get(path, query)
        items.concat(page.fetch("data"))
        yield page if block_given?
        following = page.dig("links", "next")
        return items unless following
        uri = URI(following)
        raise "Unexpected pagination destination" unless uri.scheme == "https" && uri.host == URI(BASE).host && uri.path == path
        query = URI.decode_www_form(uri.query.to_s).to_h
      end
      raise "Apple pagination exceeded its limit"
    end

    def validate_app!
      app = get("/v1/apps/#{APP_ID}").fetch("data")
      raise "Wrong App Store Connect application" unless app["id"] == APP_ID && app.dig("attributes", "bundleId") == BUNDLE_ID
      group = get("/v1/betaGroups/#{GROUP_ID}").fetch("data")
      attributes = group.fetch("attributes")
      unless attributes["name"] == GROUP_NAME && attributes["isInternalGroup"] == true && attributes["hasAccessToAllBuilds"] == true
        raise "Expected the existing internal group with automatic build access"
      end
      testers = list("/v1/betaGroups/#{GROUP_ID}/betaTesters", "limit" => "200")
      raise "The internal group has no testers" if testers.empty?
    end

    def builds
      versions = {}
      records = list("/v1/builds", "filter[app]" => APP_ID, "filter[preReleaseVersion.platform]" => "IOS", "include" => "preReleaseVersion", "limit" => "200") do |page|
        page.fetch("included", []).each { |item| versions[item["id"]] = item.dig("attributes", "version") if item["type"] == "preReleaseVersions" }
      end
      records.map do |build|
        { "id" => build.fetch("id"), "build_number" => build.dig("attributes", "version"),
          "app_version" => versions.fetch(build.dig("relationships", "preReleaseVersion", "data", "id")),
          "processing_state" => build.dig("attributes", "processingState"),
          "audience" => build.dig("attributes", "buildAudienceType"),
          "expired" => build.dig("attributes", "expired") }
      end
    end

    def ready?(build)
      raise "Apple rejected or expired the build" if build["expired"] || %w[FAILED INVALID].include?(build["processing_state"])
      return false unless build["processing_state"] == "VALID"
      raise "The uploaded build is not restricted to internal TestFlight" unless build["audience"] == "INTERNAL_ONLY"
      details = get("/v1/builds/#{build.fetch('id')}/buildBetaDetail").dig("data", "attributes")
      state = details.fetch("internalBuildState")
      if %w[PROCESSING_EXCEPTION MISSING_EXPORT_COMPLIANCE EXPIRED].include?(state)
        raise "TestFlight needs attention: #{state}"
      end
      return false unless state == "IN_BETA_TESTING"
      list("/v1/betaGroups/#{GROUP_ID}/builds", "limit" => "200").any? { |item| item["id"] == build["id"] }
    end
  end

  def self.plan(apple: Apple.new)
    guard_main!
    apple.validate_app!
    return load_plan if File.exist?(PLAN)
    version = File.read("pubspec.yaml")[/^version:\s*(\S+)/, 1]
    name, number = next_version(version, apple.builds)
    result = { "schema" => 1, "app_id" => APP_ID, "bundle_id" => BUNDLE_ID,
      "team_id" => TEAM_ID, "group_id" => GROUP_ID, "commit" => ENV.fetch("GITHUB_SHA"),
      "run_id" => ENV.fetch("GITHUB_RUN_ID"), "version_name" => name, "build_number" => number }
    write_json(PLAN, result)
    result
  end

  def self.publish(apple: Apple.new, sleeper: ->(seconds) { sleep(seconds) }, timeout: 2400)
    plan = load_plan
    apple.validate_app!
    manifest = JSON.parse(File.read(".release/ios-artifacts/manifest.json"))
    unless manifest["commit"] == plan["commit"] && manifest["version_name"] == plan["version_name"] &&
        manifest["build_number"] == plan["build_number"] && manifest["internal_only"] == true
      raise "Artifact manifest does not match the planned internal build"
    end
    ipa = ".release/ios-artifacts/whoreads.ipa"
    raise "IPA checksum mismatch" unless Digest::SHA256.file(ipa).hexdigest == manifest.fetch("sha256")
    receipt = File.exist?(RESULT) ? JSON.parse(File.read(RESULT)) : nil
    if receipt && receipt.values_at("commit", "run_id", "sha256") != [plan["commit"], plan["run_id"], manifest["sha256"]]
      raise "Prior upload receipt does not match this exact artifact and run"
    end
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    existing = apple.builds.find { |b| b["app_version"] == plan["version_name"] && b["build_number"] == plan["build_number"] }
    raise "The planned version already exists without this run's upload receipt" if existing && !receipt
    unless existing
      if receipt && receipt["upload_started"]
        raise "A previous upload attempt needs reconciliation; refusing automatic reupload"
      end
      write_json(RESULT, plan.merge("sha256" => manifest["sha256"], "upload_started" => true, "ready" => false))
      key_dir = File.join(ENV.fetch("RUNNER_TEMP"), "whoreads-asc-key")
      FileUtils.mkdir_p(key_dir, mode: 0o700)
      key_path = File.join(key_dir, "AuthKey_#{ENV.fetch('ASC_KEY_ID')}.p8")
      File.write(key_path, Base64.strict_decode64(ENV.fetch("ASC_PRIVATE_KEY_BASE64")), mode: "w", perm: 0o600)
      begin
        _output, _error, status = Open3.capture3({ "API_PRIVATE_KEYS_DIR" => key_dir },
          "xcrun", "altool", "--upload-app", "-f", ipa, "-t", "ios", "--apiKey", ENV.fetch("ASC_KEY_ID"),
          "--apiIssuer", ENV.fetch("ASC_ISSUER_ID"), "--output-format", "json")
        raise "Apple upload failed or was not confirmed; inspect Apple before retrying" unless status.success?
      ensure
        FileUtils.rm_f(key_path)
        Dir.rmdir(key_dir) if Dir.exist?(key_dir) && Dir.empty?(key_dir)
      end
    end
    loop do
      build = apple.builds.find { |b| b["app_version"] == plan["version_name"] && b["build_number"] == plan["build_number"] }
      if build && apple.ready?(build)
        result = plan.merge("sha256" => manifest["sha256"], "upload_started" => true, "ready" => true, "build_id" => build.fetch("id"), "verified_at" => Time.now.utc.iso8601)
        write_json(RESULT, result)
        puts "TestFlight internal testing ready: #{plan['version_name']} (#{plan['build_number']})"
        return result
      end
      raise "Apple processing did not finish before the timeout; upload is not testing-ready" if Process.clock_gettime(Process::CLOCK_MONOTONIC) - started >= timeout
      puts "Waiting for the exact build to become available in the existing internal group"
      sleeper.call(30)
    end
  end

  def self.notify(status:, webhook: ENV.fetch("IOS_DISCORD_WEBHOOK_URL"))
    guard_main!
    unless %r{\Ahttps://discord\.com/api/webhooks/\d+/[\w-]+\z}.match?(webhook)
      raise "Invalid Discord webhook; value omitted"
    end
    result = File.exist?(RESULT) ? JSON.parse(File.read(RESULT)) : {}
    success = status == "success" && result["ready"] == true &&
      result["commit"] == ENV.fetch("GITHUB_SHA") && result["run_id"] == ENV.fetch("GITHUB_RUN_ID")
    raise "Refusing a completion notification without verified TestFlight readiness" if status == "success" && !success
    message = success ? MESSAGE : "[WhoReads] - ios TestFlight 실패 또는 확인 필요"
    run_url = "https://github.com/#{ENV.fetch('GITHUB_REPOSITORY')}/actions/runs/#{ENV.fetch('GITHUB_RUN_ID')}"
    description = result["version_name"] ? "#{result['version_name']} (#{result['build_number']})\n#{run_url}" : run_url
    body = { "content" => message, "allowed_mentions" => { "parse" => [] },
      "embeds" => [{ "description" => description }] }
    uri = URI(webhook + "?wait=true")
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request.body = JSON.generate(body)
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 20, read_timeout: 30) { |http| http.request(request) }
    raise "Discord delivery not confirmed; do not blindly resend" unless response.is_a?(Net::HTTPSuccess)
    receipt = JSON.parse(response.body)
    raise "Discord delivery not confirmed; do not blindly resend" unless /\A\d+\z/.match?(receipt["id"].to_s) && receipt["content"] == message
    puts "Discord confirmed message #{receipt.fetch('id')}: #{message}"
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    case ARGV.fetch(0)
    when "plan"
      plan = WhoReadsTestFlight.plan
      if ENV["GITHUB_OUTPUT"]
        File.open(ENV["GITHUB_OUTPUT"], "a") { |f| f.puts("version_name=#{plan['version_name']}\nbuild_number=#{plan['build_number']}") }
      end
      puts "Planned WhoReads #{plan['version_name']} (#{plan['build_number']}) for internal TestFlight only"
    when "publish" then WhoReadsTestFlight.publish
    when "notify" then WhoReadsTestFlight.notify(status: ENV.fetch("IOS_PUBLISH_RESULT"))
    else raise "Unknown TestFlight command"
    end
  rescue StandardError => error
    warn "TestFlight automation failed (#{error.class}); credential values and response bodies omitted."
    warn error.message if error.class == RuntimeError
    exit 1
  end
end
