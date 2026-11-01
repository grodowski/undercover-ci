# frozen_string_literal: true

namespace :reports do
  desc "Print a stats email draft per account with merged PRs (read-only): reports:merge_outcomes[DAYS,INSTALLATION_ID]"
  task :merge_outcomes, %i[days installation_id] => :environment do |_task, args|
    days = Integer(args[:days] || Logic::MergeOutcomes::DAYS.first, exception: false)
    allowed = Logic::MergeOutcomes::DAYS
    abort "DAYS must be one of #{allowed.join(', ')}" unless allowed.include?(days)

    ActiveRecord::Base.while_preventing_writes do
      installations = if args[:installation_id]
                        [Installation.find_by!(installation_id: args[:installation_id])]
                      else
                        Logic::MergeOutcomes.installations_with_merges(days)
                      end
      installations.each do |installation|
        report = Logic::MergeOutcomes::Report.new(Logic::MergeOutcomes.call(installation, days:))
        puts report if report.notable?
      end
    end
  end
end
