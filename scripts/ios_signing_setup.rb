# One-time setup only. The daily TestFlight workflow uses the Developer key.
require "base64"
require "fileutils"
require "json"
require "jwt"
require "net/http"
require "openssl"
require "uri"

TEAM = "H78DY23Q9M".freeze
BUNDLE = "com.example.whoreads".freeze
NAME = "WhoReads GitHub TestFlight".freeze

def apple(method, path, attributes = nil, relationships = nil, query = {})
  uri = URI("https://api.appstoreconnect.apple.com/v1/#{path}")
  uri.query = URI.encode_www_form(query) unless query.empty?
  key = OpenSSL::PKey.read(ENV.fetch("IOS_SETUP_PRIVATE_KEY").gsub("\\n", "\n").strip)
  token = JWT.encode({ iss: ENV.fetch("ASC_ISSUER_ID"), iat: Time.now.to_i - 10,
    exp: Time.now.to_i + 600, aud: "appstoreconnect-v1" }, key, "ES256",
    { kid: ENV.fetch("IOS_SETUP_KEY_ID").strip, typ: "JWT" })
  request = method == :get ? Net::HTTP::Get.new(uri) : Net::HTTP::Post.new(uri)
  request["Authorization"] = "Bearer #{token}"
  request["Content-Type"] = "application/json"
  if method == :post
    raise "Only certificates and profiles can be created" unless %w[certificates profiles].include?(path)
    data = { type: path, attributes: attributes }
    data[:relationships] = relationships if relationships
    request.body = JSON.generate(data: data)
  end
  response = Net::HTTP.start(uri.host, uri.port, use_ssl: true,
    open_timeout: 20, read_timeout: 60) { |http| http.request(request) }
  raise "Apple setup HTTP #{response.code}; inspect Apple before retrying" unless response.is_a?(Net::HTTPSuccess)
  JSON.parse(response.body)
end

def list(path, query = {})
  page = apple(:get, path, nil, nil, query.merge("limit" => "200"))
  raise "Too many signing records; inspect Apple manually" if page.dig("links", "next")
  page.fetch("data")
end

begin
  raise "Only a manual main run can initialize signing" unless ENV["GITHUB_REF"] == "refs/heads/main" && ENV["GITHUB_EVENT_NAME"] == "workflow_dispatch"
  csr_text = ENV.fetch("IOS_SETUP_CSR")
  csr = OpenSSL::X509::Request.new(csr_text)
  raise "Unexpected CSR" unless csr.verify(csr.public_key) && csr.public_key.is_a?(OpenSSL::PKey::RSA) && csr.public_key.n.num_bits >= 2048 && csr.subject.to_a.any? { |part| part[0..1] == ["CN", NAME] }
  public_key = csr.public_key.public_to_der
  bundle = list("bundleIds", "filter[identifier]" => BUNDLE).find { |item| item.dig("attributes", "identifier") == BUNDLE }
  raise "WhoReads App ID was not found" unless bundle && bundle.dig("attributes", "seedId") == TEAM
  matching = list("certificates", "filter[certificateType]" => "DISTRIBUTION").select do |item|
    encoded = item.dig("attributes", "certificateContent")
    encoded && OpenSSL::X509::Certificate.new(Base64.strict_decode64(encoded)).public_key.public_to_der == public_key
  end
  raise "Multiple certificates match this CSR; inspect before retrying" if matching.length > 1
  cert = matching.first || apple(:post, "certificates", { certificateType: "DISTRIBUTION", csrContent: csr_text }).fetch("data")
  certificate = OpenSSL::X509::Certificate.new(Base64.strict_decode64(cert.dig("attributes", "certificateContent")))
  raise "Certificate identity mismatch or expired" unless certificate.public_key.public_to_der == public_key && certificate.not_after > Time.now && certificate.subject.to_a.any? { |part| part[0..1] == ["OU", TEAM] }
  profiles = list("profiles", "filter[name]" => NAME).select { |item| item.dig("attributes", "name") == NAME }
  raise "Multiple profiles share the setup name; inspect before retrying" if profiles.length > 1
  profile = profiles.first
  if profile
    profile_bundle = apple(:get, "profiles/#{profile.fetch('id')}/bundleId").fetch("data")
    profile_certs = list("profiles/#{profile.fetch('id')}/certificates")
    raise "Existing setup profile has different signing scope" unless profile_bundle["id"] == bundle["id"] && profile_certs.map { |item| item["id"] } == [cert["id"]]
  else
    profile = apple(:post, "profiles", { name: NAME, profileType: "IOS_APP_STORE" },
      { bundleId: { data: { type: "bundleIds", id: bundle.fetch("id") } },
        certificates: { data: [{ type: "certificates", id: cert.fetch("id") }] } }).fetch("data")
  end
  raise "Distribution profile is not active" unless profile.dig("attributes", "profileType") == "IOS_APP_STORE" && profile.dig("attributes", "profileState") == "ACTIVE"
  plaintext = JSON.generate({ team: TEAM, bundle: BUNDLE, certificate: cert.dig("attributes", "certificateContent"),
    profile: profile.dig("attributes", "profileContent") })
  # Only this Mac holds the CSR private key. Even public Actions artifacts cannot
  # reveal the profile or certificate response, and the API key is never included.
  cipher = OpenSSL::Cipher.new("aes-256-gcm").encrypt
  encryption_key = cipher.random_key
  nonce = cipher.random_iv
  cipher.auth_data = "WhoReads signing setup v1"
  ciphertext = cipher.update(plaintext) + cipher.final
  result = { schema: 1 }
  { encrypted_key: csr.public_key.public_encrypt(encryption_key, OpenSSL::PKey::RSA::PKCS1_OAEP_PADDING),
    iv: nonce, tag: cipher.auth_tag, ciphertext: ciphertext }.each { |name, value| result[name] = Base64.strict_encode64(value) }
  FileUtils.mkdir_p(".release/ios-signing-setup")
  File.write(".release/ios-signing-setup/encrypted.json", JSON.pretty_generate(result))
  puts "WhoReads distribution certificate and profile ready; result encrypted for the CSR owner"
rescue StandardError => error
  warn "Signing setup failed (#{error.class}); key material and Apple responses omitted"
  warn error.message if error.class == RuntimeError
  exit 1
end
