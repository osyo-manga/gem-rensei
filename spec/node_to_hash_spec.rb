RSpec.describe Rensei::NodeToHash do
  using Rensei::NodeToHash

  describe "#to_h" do
    let(:node) { RubyVM::AbstractSyntaxTree.parse(code) }
    let(:code) { "1 + 2" }
    let(:arguments) { {} }
    subject(:hash) { node.to_h(**arguments) }

    context "default arguments" do
      it { is_expected.to include(
        type: :SCOPE,
        children: include(
          [],
          nil,
          include(
            type: :OPCALL,
            children: include(
              include(
                type: :LIT,
                children: [1]
              ),
              :+,
              include(
                type: eq(:LIST).or(eq :ARRAY),
                children: include(
                  type: :LIT,
                  children: [2]
                )
              )
            )
          )
        )
      ) }
    end
  end
end
