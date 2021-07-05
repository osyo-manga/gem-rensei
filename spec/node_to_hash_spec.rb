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
      it { is_expected.not_to include(
        first_column: 0,
        last_column: 5,
        first_lineno: 1,
        last_lineno: 1
      ) }
    end

    context "with `ignore_codeposition: true`" do
      let(:arguments) { { ignore_codeposition: true } }
      it { is_expected.not_to include(
        first_column: 0,
        last_column: 5,
        first_lineno: 1,
        last_lineno: 1
      ) }
    end

    context "with `ignore_codeposition: false`" do
      let(:arguments) { { ignore_codeposition: false } }
      it { is_expected.to include(
        first_column: 0,
        last_column: 5,
        first_lineno: 1,
        last_lineno: 1
      ) }
    end
  end
end
