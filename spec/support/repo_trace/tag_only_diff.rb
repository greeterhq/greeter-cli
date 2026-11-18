# frozen_string_literal: true

module RepoTrace
  # Proves that an edit to an existing test file only added or changed
  # requirement/scenario tags. Both versions are normalised the same way and
  # compared; any remaining difference is a problem naming the file.
  #
  # .rb: unwrap tagged context wrappers (context, then the requirement and
  #      scenario tags, then do) whose body is only it_behaves_like lines,
  #      drop each requirement/scenario tag pair, then all whitespace.
  #      (Worded without literal tags so the trace check's text scan of
  #      spec/**/*.rb does not read this comment as a tag.)
  # .feature: drop @requirement-* / @scenario-* tokens, then all whitespace.
  #
  # Known limit: whitespace inside string literals is removed too.
  module TagOnlyDiff
    TAG = /,\s*(?:requirement|scenario):\s*'[^']*'/
    WRAPPER_OPEN = /
      ^(?<indent>[ \t]*)context\s+(?:'[^']*'|"[^"]*"),\s*
      requirement:\s*'[^']*',\s*scenario:\s*'[^']*'\s+do[ \t]*\n
    /x
    FEATURE_TAG = /@(?:requirement|scenario)-\S+/

    module_function

    def call(path:, before:, after:)
      return [] if normalise(path, before) == normalise(path, after)

      ["#{path}: changes more than requirement/scenario tags"]
    end

    def normalise(path, text)
      text = path.end_with?('.feature') ? text.gsub(FEATURE_TAG, '') : unwrap(text).gsub(TAG, '')
      text.gsub(/\s+/, '')
    end

    def unwrap(text)
      offset = 0
      while (open = WRAPPER_OPEN.match(text, offset))
        replaced = unwrap_at(text, open)
        text = replaced || text
        offset = replaced ? open.begin(0) : open.end(0)
      end
      text
    end

    # The text with one wrapper removed, or nil if it is not a pure wrapper.
    def unwrap_at(text, open)
      rest = text[open.end(0)..]
      close = rest.match(/^#{Regexp.escape(open[:indent])}end[ \t]*(?:\n|\z)/)
      return nil unless close

      body = rest[0...close.begin(0)]
      return nil unless shared_examples_only?(body)

      text[0...open.begin(0)] + body + rest[close.end(0)..]
    end

    def shared_examples_only?(body)
      body.lines.map(&:strip).all? { |line| line.empty? || line.start_with?('it_behaves_like') }
    end
  end
end
