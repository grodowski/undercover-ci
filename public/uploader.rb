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
require "net/http"
require "json"
require "pathname"
require "uri"
require "optparse"

Options = Struct.new(:commit, :lcov, :repo, :url) do
  def valid?
    (commit && !commit.empty?) &&
      (repo && !repo.empty?) &&
      (lcov && !lcov.empty?)
  end
end

class UndercoverCiCoverageUpload
  attr_reader :exitcode

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
      opts.on("--lcov LCOV_FILE", "LCOV file path") do |v|
        @options.lcov = v
      end
      opts.on("--url URL", "Custom UndercoverCI URL") do |v|
        @options.url = URI(v)
      end
    end
    @opts_parser.parse!(argv)
  end

  def upload
    unless @options.valid?
      error(@opts_parser)
      return
    end

    @options.url ||= URI("https://undercover-ci.com/v1/coverage")
    data = File.read(@options.lcov)

    unless data.size.positive?
      error("#{@options.lcov} is an empty file, is that the correct path?")
      return
    end

    coverage_data_base64 = Base64.strict_encode64(data)
    resp = Net::HTTP.post(
      @options.url,
      {
        repo: @options.repo,
        sha: @options.commit,
        lcov_base64: coverage_data_base64
      }.to_json,
      "Content-Type" => "application/json"
    )
    case resp.code.to_i
    when (200..299)
      puts("Uploaded! #{resp.code}")
    when 404
      error "Error 404: does a check for commit #{@options.commit} exist in #{@options.repo}? " \
            "Visit https://undercover-ci.com/docs or get support at jan@undercover-ci.com."
    else
      error "Error #{resp.code}, #{resp.body}. " \
            "Visit https://undercover-ci.com/docs or get support at jan@undercover-ci.com."
    end
  end

  private

  def error(message)
    @exitcode = 1
    warn(message)
  end
end

if __FILE__ == $PROGRAM_NAME
  exitcode = UndercoverCiCoverageUpload.new.upload
  exit(exitcode) unless exitcode.zero?
end
