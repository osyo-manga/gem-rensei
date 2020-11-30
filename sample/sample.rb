require "rensei"

code = <<~EOS
10.times do |i|
  puts i
end
EOS

ast = RubyVM::AbstractSyntaxTree.parse(code)
ruby = Rensei.unparse(ast)
puts ruby
# => 10.times() { |i| puts(i) }
