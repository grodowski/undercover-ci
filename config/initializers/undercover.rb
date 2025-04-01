# frozen_string_literal: true

# Temp patch to attempt fix behaviour when pull request HEAD is a merge commit
module Undercover
  class Changeset
    def head
      repo.head.target
      head_commit = repo.lookup(repo.head.target_id)
      return head_commit.parents.first if head_commit.parents.size > 1 # it's a merge commit, return head^1

      head_commit
    end
  end
end
