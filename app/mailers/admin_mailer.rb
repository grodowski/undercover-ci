# frozen_string_literal: true

class AdminMailer < ApplicationMailer
  def new_installation(installation)
    @installation = installation

    mail(
      to: ENV.fetch("ADMIN_EMAIL"),
      subject: "New installation: #{installation.installation_id}"
    )
  end

  def new_user(user)
    @user = user

    mail(
      to: ENV.fetch("ADMIN_EMAIL"),
      subject: "New user: #{user.name}"
    )
  end
end
