# frozen_string_literal: true

module CheckRuns
  class Create < Base
    def post
      client = installation_api_client(run.installation_id)
      client.post(
        "/repos/#{run.full_name}/check-runs",
        head_sha: run.sha,
        name: "Undercover CI",
        status: "queued",
        external_id: "", # TODO: create an external id
        output: {
          title: "Queued",
          summary: "A coverage check is queued and awaiting coverage data",
          text: queued_text_for_run
        },
        accept: "application/vnd.github.antiope-preview+json"
      )
      log "#{run} response: #{client.last_response.status}"
    end

    private

    # TODO: add conditional copy:
    # - if repo.user has no previous builds that are *completed*,
    # - if repo.user previous build failed
    # - if repo.user previous build had > n warnings, show how to set up locally
    # - in general, add some fun and randomness
    def queued_text_for_run
      <<-TEXT
      ⏳ Please hold on tight until coverage data is ready to analyse.

      📚 If this is your first build with Undercover CI, please keep on reading to
      learn how to set it up.

      ---

      **Undercover CI setup guide**

      1. Add `simplecov` and `simplecov-lcov` to your `Gemfile`
      2. Make sure LCOV coverage format is enabled

      ```
      # spec/spec_helper.rb
      # TODO
      ```

      3. Set up your CI so that coverage data is uploaded to Undercover CI.
      The API expects the following fields:

      ```
      {repo: "username/reponame", "sha": "$CI_COMMIT_SHA", "lcov_base64": ""}
      ```

      Please refer to the `curl` command below and customise it to suite your environment:

      ```
      # your_ci_config.yml
      # step 1 - run specs
      bundle exec rspec
      # step 2 - upload coverage
      curl -X POST -H "Content-Type: application/json" \
      -d "{\"repo\": \"grodowski/undercover-ci\", \"sha\": \"3eb49a677d75852404c898c4ecaa9b6efd335f8a\", \"lcov_base64\": \"$(cat coverage/lcov/undercover-ci.lcov | base64)\"}" \
      https://undercover-ci.com/v1/coverage

      ```

      4. 👮‍♀️ Undercover CI will scan this PR for untested methods, blocks and classes
      by combining data from the uploaded code coverage report and this diff.

      ---

      💁‍♂️ If you have any issues with the setup, please reach out to help@undercover-ci.com
      and we'll help you shortly.
      TEXT
    end
  end
end
