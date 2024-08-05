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
# ruby -e "$(curl -s https://undercover-ci.com/uploader.rb)" -- [opts]

require "base64"
require "json"
require "net/http"
require "optparse"
require "pathname"
require "uri"

Options = Struct.new(:commit, :lcov, :repo, :url, :cancel) do
  def valid?
    (commit && !commit.empty?) &&
      (repo && !repo.empty?)
  end
end

class UndercoverCiCoverageUpload
  attr_reader :exitcode, :options

  def initialize(argv = ARGV)
    @exitcode = 0
    @options = Options.new
    @opts_parser = OptionParser.new do |opts|
      opts.banner = "Usage: ruby -e \"$(curl -s https://undercover-ci.com/uploader.rb)\" -- [options]"

      opts.on("--repo REPO", "Repository name") do |v|
        @options.repo = v
      end
      opts.on("--commit COMMIT", "Commit SHA") do |v|
        @options.commit = v
      end
      opts.on("--cancel", "Cancel coverage check") do |v|
        @options.cancel = v
      end
      opts.on("--lcov LCOV_FILE", "LCOV file path") do |v|
        @options.lcov = v
      end
      opts.on("--url URL", "Custom UndercoverCI URL") do |v|
        @options.url = URI(v)
      end
    end
    @opts_parser.parse!(argv)
    @options.url ||= URI("https://undercover-ci.com/v1/coverage")
  end

  def valid?
    return true if @options.valid?

    error(@opts_parser)
    false
  end

  def upload
    unless @options.valid?
      error(@opts_parser)
      return self
    end

    data = File.read(@options.lcov)

    unless data.size.positive?
      error("#{@options.lcov} is an empty file, is that the correct path?")
      return self
    end

    coverage_data_base64 = Base64.strict_encode64(data)
    request(
      Net::HTTP::Post,
      @options.url,
      {
        repo: @options.repo,
        sha: @options.commit,
        lcov_base64: coverage_data_base64
      }.to_json
    )
  end

  def cancel
    request(
      Net::HTTP::Delete,
      @options.url,
      {
        repo: @options.repo,
        sha: @options.commit
      }.to_json
    )
  end

  private

  def request(method, url, body)
    http = Net::HTTP.start(url.hostname, use_ssl: url.instance_of?(URI::HTTPS))
    req = method.new(url.path, "Content-Type" => "application/json")
    req.body = body
    resp = http.request(req)
    case resp.code.to_i
    when (200..299)
      puts("Done! #{resp.code}")
    when 404
      error "Error 404: does a check for commit #{@options.commit} exist in #{@options.repo}? " \
            "Visit https://undercover-ci.com/docs or get support at jan@undercover-ci.com."
    else
      error "Error #{resp.code}, #{resp.body}. " \
            "Visit https://undercover-ci.com/docs or get support at jan@undercover-ci.com."
    end
    self
  end

  def error(message)
    @exitcode = 1
    warn(message)
  end
end

if __FILE__ == $PROGRAM_NAME
  uploader = UndercoverCiCoverageUpload.new
  exit(uploader.exitcode) unless uploader.valid?
  if uploader.options.cancel
    uploader.cancel
  else
    uploader.upload
  end
  exit(uploader.exitcode)
end
