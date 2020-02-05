require 'optparse'

module GitChain
  module Commands
    class Reset < Command
      include Options::ChainName

      def description
        "Resets all branches of the chain to upstream"
      end

      def run(options)
        raise(Abort, "Current branch '#{Git.current_branch}' is not in a chain.") unless options[:chain_name]

        chain = GitChain::Models::Chain.from_config(options[:chain_name])
        raise(Abort, "Chain '#{options[:chain_name]}' does not exist.") if chain.empty?

        log_names = chain.branch_names.map { |b| "{{cyan:#{b}}}" }.join(' -> ')
        puts_debug("Resetting chain {{info:#{chain.name}}} [#{log_names}]")

        branches_to_reset = chain.branches[1..-1]

        raise(Abort, "No branches to reset for chain '#{chain.name}'.") if branches_to_reset.empty?

        updates = 0

        branches_to_reset.each do |branch|
          begin
            parent_sha = Git.rev_parse(branch.parent_branch)
            if parent_sha == branch.branch_point
              puts_debug("Branch {{info:#{branch.name}}} is already up-to-date.")
              next
            end

            updates += 1

            if parent_sha != branch.branch_point && forwardable_branch_point?(branch)
              puts_info("Auto-forwarding #{branch.name} to #{branch.parent_branch}")
              Git.set_config("branch.#{branch.name}.branchPoint", parent_sha)
              branch.branch_point = parent_sha
            end

=begin
            args = ["rebase", "--keep-empty", "--onto", branch.parent_branch, branch.branch_point, branch.name]
            puts_debug_git(*args)
            Git.exec(*args)
            Git.set_config("branch.#{branch.name}.branchPoint", parent_sha, scope: :local)
            # validate the parameters
=end
          rescue GitChain::Git::Failure => e
            puts_warning(e.message)

            puts_error("Cannot reset #{branch.name} to #{branch.parent_branch}.")
            puts_error("Fix the error and run {{command:git chain reset}} again.")
            raise(AbortSilent)
          end
        end

        if updates.positive?
          puts_success("Chain {{info:#{chain.name}}} successfully reset.")
        else
          puts_info("Chain {{info:#{chain.name}}} is already up-to-date.")
        end
      end
    end
  end
end
