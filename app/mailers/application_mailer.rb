# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  default from: "undercover-ci <notifications@undercover-ci.com>"
  layout "mailer"
end
