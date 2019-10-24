# frozen_string_literal: true

#  _____________________________________
# < UndercoverCI coverage uploader 🚀 >
#  -------------------------------------
#         \   ^__^
#          \  (oo)\_______
#             (__)\       )\/\
#                 ||----w |
#                 ||     ||
# Usage:
# ruby -e "$(curl -s https://undercover-ci.com/uploader.rb) -- [opts]"

require "base64"
require "net/http"
require "json"
require "pathname"
require "uri"
require "optparse"

options = Struct.new(:commit, :lcov, :repo, :url) do
  def valid?
    commit && repo && lcov
  end
end.new

opts_parser = OptionParser.new do |opts|
  opts.banner = "Usage: ruby -e \"$(curl -s https://undercover-ci.com/uploader.rb)\" -- [options]"

  opts.on("--repo REPO", "Repository name") do |v|
    options.repo = v
  end
  opts.on("--commit COMMIT", "Commit SHA") do |v|
    options.commit = v
  end
  opts.on("--lcov LCOV_FILE", "LCOV file path") do |v|
    options.lcov = v
  end
  opts.on("--url URL", "Custom UndercoverCI URL") do |v|
    options.url = URI(v)
  end
end
opts_parser.parse!

unless options.valid?
  puts opts_parser
  exit 1
end

options.url ||= URI("https://undercover-ci.com/v1/coverage")
data = File.read(options.lcov)
coverage_data_base64 = Base64.strict_encode64(data)

resp = Net::HTTP.post(
  options.url,
  {
    repo: options.repo,
    sha: options.commit,
    lcov_base64: coverage_data_base64
  }.to_json,
  "Content-Type" => "application/json"
)
puts(resp.code)
