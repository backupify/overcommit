module Overcommit::Hook::PreCommit
  # Runs `xmllint` against any modified XML files.
  #
  # @see http://xmlsoft.org/xmllint.html
  class XmlLint < Base
    MESSAGE_REGEX = /^(?<file>[^:]+):(?<line>\d+):/

    def run
      result = execute(command + applicable_files)
      output = result.stderr.chomp

      return :pass if result.success? && output.empty?

      # example message:
      #   path/to/file.xml:1: parser error : Error message
      extract_messages(
        output.split("\n").grep(MESSAGE_REGEX),
        MESSAGE_REGEX
      )
    end
  end
end
