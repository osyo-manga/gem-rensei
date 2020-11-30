require "rensei"

class Hash
  # ノードの Hash をネストして操作する拡張する
  def each_node(&block)
    return enum_for(:each_node) unless block
    self[:children].each { |node|
      block.call self
      if Hash === node
        node.each_node(&block)
      end
    }
  end
end

# RubyVM::AbstractSyntaxTree::Node から Hash に変換する拡張
# RubyVM::AbstractSyntaxTree::Node#to_h で変換できる
using Rensei::NodeToHash


def bocchi &block
  # ブロックの中身を AST に変換
  ast = RubyVM::AbstractSyntaxTree.of(block)

  # AST から必要な node だけ抽出
  node = ast.children.last

  # AST の node から Hash に変換
  node_h = node.to_h

  # AST の type の意味を変更
  # hoge.foo から hoge&.foo に変換する
  node_h.each_node { |node|
    node[:type] = :QCALL if node[:type] == :CALL
  }

  # 変換した AST の Hash を Ruby のコードに戻す
  code = Rensei.unparse(node_h)

  # メソッドの呼び出し元のコンテキストで評価する
  block.binding.eval(code)
end


hoge1 = nil
hoge2 = Struct.new(:foo).new(nil)
hoge3 = Struct.new(:foo).new(bar: "hogehoge")

# . を &. に変換して実行する
bocchi {
  pp hoge1.foo[:bar]    # => nil
  pp hoge2.foo[:bar]    # => nil
  pp hoge3.foo[:bar]    # => "hogehoge"
}

