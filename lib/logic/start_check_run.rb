# frozen_string_literal: true

module Logic
  class StartCheckRun
    include ClassLoggable

    def self.call(check_run_info)
      new(check_run_info).create_and_queue_check_run
    end

    attr_reader :check_run_info

    def initialize(check_run_info)
      @check_run_info = check_run_info
    end

    def create_and_queue_check_run
      find_installation

      unless branch_matches_filter?
        log "StartCheckRun skipping due to branch filter, branch: #{branch_name}, repo: #{repo_full_name}"
        return
      end
      unless save_new_coverage_check
        log "StartCheckRun exiting early, #{check_run_info} is #{coverage_check.state}"
        return
      end

      Logic::UpdateCoverageCheckState.new(coverage_check).await_coverage
      CreateCheckRunJob.perform_later(coverage_check.id)

      ExpireCheckJob.set(wait: coverage_check.expire_check_wait).perform_later(coverage_check.id)
    end

    private

    attr_reader :coverage_check, :installation

    def find_installation
      @installation = Installation.find_by!(installation_id: check_run_info.installation_id)
    end

    def save_new_coverage_check
      CoverageCheck.transaction do
        CoverageCheck.lock_repo_sha(repo_full_name, check_run_info.sha)
        build_coverage_check
        next false unless coverage_check.state == :created

        coverage_check.repo = check_run_info.payload.repository
        coverage_check.check_suite = check_run_info.payload.check_suite
        coverage_check.save!
      end
    end

    # An upload with --pull-request may have created the check before this webhook arrived
    def build_coverage_check
      @coverage_check = upload_created_check || @installation.coverage_checks.find_or_initialize_by(
        head_sha: check_run_info.sha,
        base_sha: check_run_info.compare
      )
    end

    def upload_created_check
      CoverageCheck.where(check_suite: nil).for_repo_sha(repo_full_name, check_run_info.sha)
    end

    def branch_name
      check_run_info.payload.check_suite&.fetch("head_branch", "")
    end

    def branch_matches_filter?
      installation.branch_matches_filter?(branch_name, repo_full_name)
    end

    def repo_full_name
      check_run_info.full_name
    end
  end
end
