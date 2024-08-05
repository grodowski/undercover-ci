# frozen_string_literal: true

require "open3"

module Git
  # Responsible for fetching a new Git ref for analysis
  class Fetch
    def self.perform(ref, dir, options)
      new(ref, dir, options).perform
    end

    attr_reader :ref, :dir, :options

    def initialize(ref, dirname, options)
      @ref = ref
      @dir = dirname
      @options = options
    end

    def perform
      cmd = "GIT_TERMINAL_PROMPT=0 cd #{dir} && git fetch origin #{ref} #{options}"
      Open3.popen3(cmd) do |_s_in, _s_out, s_err, wait_thr|
        err_msg = s_err.read
        raise GitError, err_msg if wait_thr.value.exitstatus.nonzero?
      end
    end
  end
end
