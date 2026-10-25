# frozen_string_literal: true

# Uploads are unauthenticated and can make GitHub API calls, so they are limited per repo and IP.
# The limit is well above what a CI build matrix uploads.
module CoverageUploadRateLimit
  extend ActiveSupport::Concern

  UPLOADS_PER_MINUTE = 30

  included do
    rate_limit to: UPLOADS_PER_MINUTE, within: 1.minute, by: :rate_limit_key, with: :render_rate_limited
  end

  private

  def rate_limit_key
    "#{params[:repo].to_s[0, 140]}:#{request.remote_ip}"
  end

  def render_rate_limited
    @error_message = "Too many coverage uploads for this repository, please retry in a minute."
    render "shared/generic_error", format: :json, status: :too_many_requests
  end
end
