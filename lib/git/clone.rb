# frozen_string_literal: true

require "open3"

module Git
  # Responsible for cloning a Git repository into a given tempdir
  class Clone
    def self.perform(repo_url, dir, options)
      new(repo_url, dir, options).perform
    end

    attr_reader :repo_url, :dir, :options

    def initialize(repo_url, dirname, options)
      raise ArgumentError, "repo_url must start with https://" unless repo_url.match?(/^https:\/\//)

      @repo_url = repo_url
      @dir = dirname
      @options = options
    end

    def perform
      cmd = "GIT_TERMINAL_PROMPT=0 git clone #{options} #{repo_url} #{dir}"
      Open3.popen3(cmd) do |_s_in, _s_out, s_err, wait_thr|
        err_msg = s_err.read
        raise GitError, err_msg unless wait_thr.value.exitstatus.zero?
      end
    end
  end
end
