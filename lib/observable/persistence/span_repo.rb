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
        self.class.new(spans: group_by(&:trace_id).find { |_trace_id, spans| spans.count > 1 }.second)
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

      def to_block(query)
        lambda do |object|
          object.attrs.transform_keys(&:to_s).slice(*query.transform_keys(&:to_s).keys) == query.transform_keys(&:to_s)
        end
      end
    end
  end
end
