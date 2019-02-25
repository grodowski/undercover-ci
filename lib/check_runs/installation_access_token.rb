# frozen_string_literal: true

module CheckRuns
  class InstallationAccessToken < Base
    def get
      installation_token(run.installation_id)
    end
  end
end
