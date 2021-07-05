require "json"

module Rensei
  module NodeToHash
    refine RubyVM::AbstractSyntaxTree::Node do
      using NodeToHash
      using Module.new {
        refine Object do
          def to_h
            to_s
          end
        end
        [
          NilClass,
          FalseClass,
          TrueClass,
          Numeric,
          String,
          Symbol,
          Array,
          Regexp,
        ].each { |klass|
          refine klass do
            def to_h
              self
            end
          end
        }
      }

      def to_h
        {
          type: type,
          children: children.map(&:to_h),
        }
      end
    end
  end
end
