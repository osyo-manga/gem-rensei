require_relative "./spec_helper.rb"
require_relative "./helpers/unparser.rb"

RSpec.describe Rensei::Unparser::Ruby3_0_0, ruby_version: "3.0.0"... do
  include UnparserHelper
  extend UnparserHelper::ClassMethods

  let(:ast) { RubyVM::AbstractSyntaxTree.parse(code) }
  let(:node) { ast.children.last }

  subject { node }

  describe "NODE_ITER" do
    parse_by "proc { _1 }" do
      it { is_expected.to unparsed "proc() { _1 }" }
    end
    parse_by "proc { _9 }" do
      it { is_expected.to unparsed "proc() { _9 }" }
    end
    parse_by "proc { _10 }" do
      it { is_expected.to unparsed "proc() { _10 }" }
    end
    parse_by "proc { |_10| _10 }" do
      it { is_expected.to unparsed "proc() { |_10| _10 }" }
    end
  end

  describe "NODE_DEFN" do
    parse_by "def hoge = 42", ruby_version: "3.0.0"..."3.1.0" do
      it { is_expected.to unparsed "def hoge = 42" }
      it { is_expected.to type_of :DEFN }
    end
    parse_by "def hoge() = 42" do
      it { is_expected.to unparsed "def hoge()\n  42\nend" }
      it { is_expected.to type_of :DEFN }
    end
    parse_by "def hoge(a) = 42" do
      it { is_expected.to unparsed "def hoge(a)\n  42\nend" }
      it { is_expected.to type_of :DEFN }
    end
  end

  describe "NODE_DEFS" do
    parse_by "def obj.hoge = 42", ruby_version: "3.0.0"..."3.1.0" do
      it { is_expected.to unparsed "def obj.hoge = 42" }
      it { is_expected.to type_of :DEFS }
    end
    parse_by "def obj.hoge() = 42" do
      it { is_expected.to unparsed "def obj.hoge()\n  42\nend" }
      it { is_expected.to type_of :DEFS }
    end
    parse_by "def obj.hoge(a) = 42" do
      it { is_expected.to unparsed "def obj.hoge(a)\n  42\nend" }
      it { is_expected.to type_of :DEFS }
    end
  end

  describe "NODE_CASE3" do
    parse_by "42 => b" do
      it { is_expected.to unparsed "42 => b\n  \n" }
      it { is_expected.to type_of :CASE3 }
    end
    parse_by "user => { name:, age: }" do
      it { is_expected.to unparsed "user => { name: name, age: age }\n  \n" }
      it { is_expected.to type_of :CASE3 }
    end
    parse_by "42 in b" do
      it { is_expected.to unparsed "case 42\nin b\n  true\nelse\n  false\nend" }
      it { is_expected.to type_of :CASE3 }
    end
    parse_by "user in { name:, age: }" do
      it { is_expected.to unparsed "case user\nin { name: name, age: age }\n  true\nelse\n  false\nend" }
      it { is_expected.to type_of :CASE3 }
    end
  end
end
