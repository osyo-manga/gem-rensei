require "json"

module Rensei
  module NodeToHash
    refine RubyVM::AbstractSyntaxTree::Node do
      using NodeToHash
      using Module.new {
        refine Object do
          def to_hashable
            to_s
          end
        end
        [
          NilClass,
          FalseClass,
          TrueClass,
          Array,
          Symbol,
          Numeric,
          Regexp,
        ].each { |klass|
          refine klass do
            def to_hashable
              self
            end
          end
        }
      }

      def to_hashable(ignore_codeposition: true, &block)
        block = :to_hashable unless block
        {
          type: type,
          children: children.map(&block),
        }.tap { |it|
          it.merge!(
            first_column: first_column,
            last_column:  last_column,
            first_lineno: first_lineno,
            last_lineno:  last_lineno
          ) unless ignore_codeposition
        }
      end

      def to_json(ignore_codeposition: true)
        to_hashable(ignore_codeposition: ignore_codeposition, &:to_json)
      end

      def to_h(ignore_codeposition: true)
        to_hashable(ignore_codeposition: ignore_codeposition)
      end
    end
  end
end
