require "dry-struct"

module Observable
  module Persistence
    class Span < Dry::Struct
      attribute :id, Dry.Types::String
      attribute :name, Dry.Types::String
      attribute :kind, Dry.Types::Symbol
      attribute :trace_id, Dry.Types::String
      attribute :attrs, Dry.Types::Hash

      # ANSI Color constants
      RESET = "\e[0m"
      BOLD = "\e[1m"
      DIM = "\e[2m"
      CYAN = "\e[36m"
      YELLOW = "\e[33m"
      GREEN = "\e[32m"
      BLUE = "\e[34m"
      MAGENTA = "\e[35m"
      WHITE = "\e[37m"

      def hex_trace_id
        trace_id
      end

      def hex_span_id
        id
      end

      def code_namespace
        attrs["code.namespace"] || attrs["messaging.sidekiq.job_class"] || ""
      end

      def producer?
        kind == :producer
      end

      def consumer?
        kind == :consumer
      end

      def self.from_spandata(span_or_spandata)
        new(
          id: span_or_spandata.hex_span_id,
          trace_id: span_or_spandata.hex_trace_id,
          name: span_or_spandata.name,
          kind: span_or_spandata.kind,
          attrs: span_or_spandata.attributes
        )
      end

      def self.from_span_or_spandata(span_or_spandata)
        if span_or_spandata.is_a?(Span)
          span_or_spandata
        else
          from_spandata(span_or_spandata)
        end
      end

      def inspect
        to_h
      end

      def ai
        output = []
        output << "  #{colorize(name, CYAN, BOLD)}"
        output << "  id: #{colorize(id, WHITE)} "

        if attrs.any?
          attrs.each do |key, value|
            output << "    #{colorize(key, YELLOW)}: #{colorize_value(value)}"
          end
        end

        output << ""
        output.join("\n")
      end

      private

      def colorize(text, color, style = nil)
        styled_text = style ? "#{style}#{text}#{RESET}" : text
        "#{color}#{styled_text}#{RESET}"
      end

      def colorize_kind(kind)
        case kind.to_s
        when "internal"
          colorize(kind, GREEN)
        when "producer"
          colorize(kind, BLUE)
        when "consumer"
          colorize(kind, MAGENTA)
        else
          colorize(kind, WHITE)
        end
      end

      def colorize_value(value)
        case value
        when String
          colorize("\"#{value}\"", GREEN)
        when Numeric
          colorize(value.to_s, BLUE)
        when TrueClass, FalseClass
          colorize(value.to_s, MAGENTA)
        when NilClass
          colorize("null", DIM)
        else
          colorize(value.inspect, WHITE)
        end
      end
    end
  end
end
