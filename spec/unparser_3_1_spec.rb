require_relative "./spec_helper.rb"
require_relative "./helpers/unparser.rb"

RSpec.describe Rensei::Unparser::Ruby3_1_0, ruby_version: "3.1.0"... do
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
    parse_by "def hoge() = 42" do
      it { is_expected.to unparsed "def hoge()\n  42\nend" }
      it { is_expected.to type_of :DEFN }
    end
    parse_by "def hoge(a) = 42" do
      it { is_expected.to unparsed "def hoge(a)\n  42\nend" }
      it { is_expected.to type_of :DEFN }
    end
    parse_by "def hoge = puts 42" do
      it { is_expected.to unparsed "def hoge()\n  puts(42)\nend" }
      it { is_expected.to type_of :DEFN }
    end
    parse_by "def hoge(a) = puts a" do
      it { is_expected.to unparsed "def hoge(a)\n  puts(a)\nend" }
      it { is_expected.to type_of :DEFN }
    end
  end

  describe "NODE_DEFS" do
    parse_by "def obj.hoge = 42" do
      it { is_expected.to unparsed "def obj.hoge()\n  42\nend" }
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
    parse_by "def obj.hoge = puts 42" do
      it { is_expected.to unparsed "def obj.hoge()\n  puts(42)\nend" }
      it { is_expected.to type_of :DEFS }
    end
    parse_by "def obj.hoge(a) = puts a" do
      it { is_expected.to unparsed "def obj.hoge(a)\n  puts(a)\nend" }
      it { is_expected.to type_of :DEFS }
    end
  end

  describe "NODE_ARYPTN" do
    parse_by(<<~'EOS') do
        case value
        in [^(a)]
        end
      EOS
      it { is_expected.to unparsed "case value\nin [^(a)]\n  \n\nend" }
    end
    parse_by(<<~'EOS') do
        case value
        in [^(a + b)]
        end
      EOS
      it { is_expected.to unparsed "case value\nin [^((a + b))]\n  \n\nend" }
    end
    parse_by(<<~'EOS') do
        case value
        in [^(proc { a; b })]
        end
      EOS
      it { is_expected.to unparsed "case value\nin [^(proc() { begin a; b; end })]\n  \n\nend" }
    end
  end

  describe "NODE_HSHPTN" do
    parse_by(<<~'EOS') do
        case value
        in { a: ^(a) }
        end
      EOS
      it { is_expected.to unparsed "case value\nin { a: ^(a) }\n  \n\nend" }
    end
    parse_by(<<~'EOS') do
        case value
        in { a: ^(a + b) }
        end
      EOS
      it { is_expected.to unparsed "case value\nin { a: ^((a + b)) }\n  \n\nend" }
    end
    parse_by(<<~'EOS') do
        case value
        in { a: ^(proc { a; b }) }
        end
      EOS
      it { is_expected.to unparsed "case value\nin { a: ^(proc() { begin a; b; end }) }\n  \n\nend" }
    end
  end
end
