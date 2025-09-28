require_relative "span"

module Observable
  module Persistence
    class SpanRepo
      include Enumerable

      def initialize(spans:)
        @spans = spans.map { |span_or_spandata| Span.from_span_or_spandata(span_or_spandata) }
      end

      def each(&)
        @spans.each(&)
      end

      def in_code_namespace(namespace)
        select { |span| span.code_namespace == namespace }
      end

      def in_root_trace
        result = group_by(&:trace_id).find { |_trace_id, spans| spans.count > 1 }
        if result
          self.class.new(spans: result.last)
        else
          self.class.new(spans: [])
        end
      end

      def one_and_only!
        if one?
          first
        else
          raise ArgumentError, "Expected 1 span, but found #{count}: #{to_a}"
        end
      end

      def find_one!(attrs: {}, &block)
        block = to_block(attrs) if attrs.any? && !block_given?

        if one?(&block)
          find(&block)
        elsif empty?(&block)
          raise_none_found
        else
          raise_too_many_found(&block)
        end
      end

      def empty?(&)
        count(&).zero?
      end

      def raise_none_found
        raise ArgumentError, "No spans found"
      end

      def raise_too_many_found(&)
        matched = select(&)
        raise ArgumentError, "Too many spans found:\n#{matched.inspect}"
      end

      def find_by!(name:)
        span = find { |s| s.name == name }
        span || raise(Observable::NotFound, "No spans found with name: #{name}\n\nSpans:\n#{ai}")
      end

      def where(criteria)
        matching_spans = select { |span| matches_criteria?(span, criteria) }
        self.class.new(spans: matching_spans)
      end

      def to_block(query)
        lambda do |object|
          object.attrs.transform_keys(&:to_s).slice(*query.transform_keys(&:to_s).keys) == query.transform_keys(&:to_s)
        end
      end

      def ai
        grouped_spans = group_by(&:trace_id)
        output = []

        grouped_spans.each do |trace_id, spans|
          output << colorize_trace_header(trace_id)
          spans.each do |span|
            output << span.ai
          end
        end

        output.join("\n")
      end

      private

      def matches_criteria?(span, criteria)
        criteria.all? do |key, expected_value|
          if expected_value.is_a?(Hash)
            # Handle nested hash syntax like {code: {return: "hello"}}
            nested_hash = get_value(span.attrs, key)
            return false unless nested_hash.is_a?(Hash)
            expected_value.all? do |nested_key, nested_value|
              get_value(nested_hash, nested_key) == nested_value
            end
          else
            # Handle simple keys and dot notation
            get_value(span.attrs, key) == expected_value
          end
        end
      end

      def get_value(hash, key)
        if key.is_a?(String) && key.include?(".")
          # Handle dot notation like "code.return"
          key.split(".").reduce(hash) do |current_hash, nested_key|
            return nil unless current_hash.is_a?(Hash)
            current_hash[nested_key] || current_hash[nested_key.to_s]
          end
        else
          # Handle simple keys (try both symbol and string)
          hash[key] || hash[key.to_s]
        end
      end

      def colorize_trace_header(trace_id)
        # Use the same color constants from Span
        cyan = "\e[36m"
        bold = "\e[1m"
        reset = "\e[0m"

        "#{cyan}#{bold}#{trace_id}#{reset}"
      end
    end
  end
end
