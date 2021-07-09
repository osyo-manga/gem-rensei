require_relative "./spec_helper.rb"
require_relative "./helpers/unparser.rb"

RSpec.describe Rensei::Unparser::Ruby2_7_0, ruby_version: "2.7.0"... do
  include UnparserHelper
  extend UnparserHelper::ClassMethods

  let(:ast) { RubyVM::AbstractSyntaxTree.parse(code) }
  let(:node) { ast.children.last }

  subject { node }

  describe "NODE_CASE3" do
    parse_by "case value; in pattern; end" do
      it { is_expected.to unparsed "case value\nin pattern\n  \n\nend" }
      it { is_expected.to type_of :CASE3 }
    end
    parse_by "case value; in pattern; end" do
      it { is_expected.to unparsed "case value\nin pattern\n  \n\nend" }
      it { is_expected.to type_of :CASE3 }
    end
    parse_by "case value; in pattern; hoge; else; foo; end" do
      it { is_expected.to unparsed "case value\nin pattern\n  hoge\nelse\n  begin; foo; end\nend" }
      it { is_expected.to type_of :CASE3 }
    end
    parse_by "case value; in pattern1; hoge; in pattern2; foo; end" do
      it { is_expected.to unparsed "case value\nin pattern1\n  hoge\nin pattern2\n  foo\n\nend" }
      it { is_expected.to type_of :CASE3 }
    end

    xdescribe "Guard clauses" do

    end
  end

  describe "NODE_IN" do
    parse_by(<<~'EOS') do
        case value
        in [1, 2]
          hoge
        end
      EOS
      it { is_expected.to unparsed "case value\nin [1, 2]\n  hoge\n\nend" }
    end

    xparse_by(<<~'EOS') do
        case value
        in [1, 2]
          hoge
        in { a:, b: }
          bar
        in other
          foo
        end
      EOS
      it { is_expected.to unparsed "case value\nin [1, 2]\n  hoge\n\nend" }
    end
  end

  describe "NODE_ARYPTN" do
    parse_by(<<~'EOS') do
        case value
        in [String, Integer, "hoge"]
          hoge
        end
      EOS
      it { is_expected.to unparsed "case value\nin [String, Integer, \"hoge\"]\n  hoge\n\nend" }
    end
    parse_by(<<~'EOS') do
        case value
        in [String, [1, ["foo", Integer]], "hoge"]
          hoge
        end
      EOS
      it { is_expected.to unparsed "case value\nin [String, [1, [\"foo\", Integer]], \"hoge\"]\n  hoge\n\nend" }
    end

    describe "[pre, rest, post]" do
      context "name rest" do
        parse_by(<<~'EOS') do
            case value
            in [Integer, Integer, *hoge]
            end
          EOS
          it { is_expected.to unparsed "case value\nin [Integer, Integer, *hoge]\n  \n\nend" }
        end
        parse_by(<<~'EOS') do
            case value
            in [*hoge, Integer, Integer]
              hoge
            end
          EOS
          it { is_expected.to unparsed "case value\nin [*hoge, Integer, Integer]\n  hoge\n\nend" }
        end
        parse_by(<<~'EOS') do
            case value
            in [Integer, String, *hoge, Integer, String]
              hoge
            end
          EOS
          it { is_expected.to unparsed "case value\nin [Integer, String, *hoge, Integer, String]\n  hoge\n\nend" }
        end
      end

      context "no name rest" do
        parse_by(<<~'EOS') do
            case value
            in [Integer, Integer, *]
            end
          EOS
          it { is_expected.to unparsed "case value\nin [Integer, Integer, *]\n  \n\nend" }
        end
        parse_by(<<~'EOS') do
            case value
            in [*, Integer, Integer]
              hoge
            end
          EOS
          it { is_expected.to unparsed "case value\nin [*, Integer, Integer]\n  hoge\n\nend" }
        end
        parse_by(<<~'EOS') do
            case value
            in [Integer, String, *, Integer, String]
              hoge
            end
          EOS
          it { is_expected.to unparsed "case value\nin [Integer, String, *, Integer, String]\n  hoge\n\nend" }
        end
      end

      context "other" do
        parse_by(<<~'EOS') do
            case value
            in [Integer, [*, Integer, [String, *foo, Integer]], *hoge]
            end
          EOS
          it { is_expected.to unparsed "case value\nin [Integer, [*, Integer, [String, *foo, Integer]], *hoge]\n  \n\nend" }
        end
      end
    end

    describe "const" do
      parse_by(<<~'EOS') do
          case value
          in Array[a, b]
          end
        EOS
        it { is_expected.to unparsed "case value\nin Array[a, b]\n  \n\nend" }
      end
      parse_by(<<~'EOS') do
          case value
          in Array[a, Array[b, 1] | Array[c, 2]]
          end
        EOS
        it { is_expected.to unparsed "case value\nin Array[a, Array[b, 1] | Array[c, 2]]\n  \n\nend" }
      end
    end

    describe "or" do
      parse_by(<<~'EOS') do
          case value
          in [Float | Integer]
          end
        EOS
        it { is_expected.to unparsed "case value\nin [Float | Integer]\n  \n\nend" }
      end
      parse_by(<<~'EOS') do
          case value
          in [Float | Integer | Array, [Float | Integer], *]
          end
        EOS
        it { is_expected.to unparsed "case value\nin [Float | Integer | Array, [Float | Integer], *]\n  \n\nend" }
      end
      parse_by(<<~'EOS') do
          case value
          in [Float | Integer | [Hash | Array]]
          end
        EOS
        it { is_expected.to unparsed "case value\nin [Float | Integer | [Hash | Array]]\n  \n\nend" }
      end
    end

    describe "Variable binding" do
      parse_by(<<~'EOS') do
          case value
          in [NilClass, Integer => hoge, String => foo, [Hash => bar, Float]]
          end
        EOS
        it { is_expected.to unparsed "case value\nin [NilClass, Integer => hoge, String => foo, [Hash => bar, Float]]\n  \n\nend" }
      end
    end

    describe "Variable pinning" do
      parse_by(<<~'EOS') do
          expr = 18
          case value
          in [^expr, [^expr], ^expr]
          end
        EOS
        it { is_expected.to unparsed "begin (expr = 18); case value\nin [^expr, [^expr], ^expr]\n  \n\nend; end" }
      end
    end
  end
end
