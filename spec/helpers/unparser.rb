module UnparserHelper
  module ClassMethods
    using Rensei::NodeToHash
    #
    # Expect failure print
    #   -> BLOCK parse by `hoge; foo` should unparsed "hoge; fo"
    #
    def parse_by(code, **kwd, &block)
      context "parse by `#{code}`", **kwd do
        let(:code) { code }
        it { expect { RubyVM::AbstractSyntaxTree.parse(code) }.not_to raise_error }
        it { expect(RubyVM::AbstractSyntaxTree.parse(Rensei::Unparser.unparse(node)).children.last.to_h).to eq node.to_h }
        instance_eval(&block) if block
      end
    end

    def xparse_by(code, &block)
      xcontext "parse by `#{code}`" do
        let(:code) { code }
        instance_eval(&block) if block
      end
    end
  end

  def ruby_version_is(version, &block)
    context version, ruby_version: version, &block
  end

  def unparsed(code)
    satisfy("be `#{Rensei::Unparser.unparse(node).inspect}`") { |node| code == Rensei::Unparser.unparse(node) }
  end

  def type_of(type)
    satisfy("be type `:#{node.type}`") { |node| node.type == type }
  end

  def children_type_of(type, nth: 0)
    satisfy("be type `:#{node.children[nth].type}`") { |node| node.children[nth].type == type }
  end
end
