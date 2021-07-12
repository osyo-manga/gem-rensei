require_relative "./spec_helper.rb"
require_relative "./helpers/unparser.rb"

RSpec.describe Rensei::Unparser::Ruby3_0_0, ruby_version: "3.0.0"... do
  include UnparserHelper
  extend UnparserHelper::ClassMethods

  let(:ast) { RubyVM::AbstractSyntaxTree.parse(code) }
  let(:node) { ast.children.last }

  subject { node }

  describe "NODE_DEFN" do
    parse_by "def hoge = 42" do
      it { is_expected.to unparsed "def hoge()\n  42\nend" }
      it { is_expected.to type_of :DEFN }
    end
  end
end
