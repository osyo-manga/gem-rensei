require_relative "./spec_helper.rb"
require_relative "./helpers/unparser.rb"

RSpec.describe Rensei::Unparser do
  include UnparserHelper
  extend UnparserHelper::ClassMethods

  let(:ast) { RubyVM::AbstractSyntaxTree.parse(code) }
  let(:node) { ast.children.last }

  subject { node }

  describe "NODE_BLOCK" do
    parse_by "hoge; foo" do
      it { is_expected.to unparsed "begin hoge; foo; end" }
      it { is_expected.to type_of :BLOCK }
    end

    parse_by "hoge\nfoo" do
      it { is_expected.to unparsed "begin hoge; foo; end" }
      it { is_expected.to type_of :BLOCK }
    end
  end

  describe "NODE_IF" do
    parse_by "if x == 1 then hoge end" do
      it { is_expected.to unparsed(<<~EOS.chomp) }
        if (x == 1)
          hoge
        end
      EOS
      it { is_expected.to type_of :IF }
    end
    parse_by "if x == 1 then hoge else foo end" do
      it { is_expected.to unparsed(<<~EOS.chomp) }
        if (x == 1)
          hoge
        else
          foo
        end
      EOS
    end
    parse_by "if cond then hoge elsif cond2 then foo else bar end" do
      it { is_expected.to unparsed(<<~EOS.chomp) }
        if cond
          hoge
        else
          if cond2
          foo
        else
          bar
        end
        end
      EOS
    end
    parse_by "hoge if x == 1" do
      it { is_expected.to unparsed(<<~EOS.chomp) }
        if (x == 1)
          hoge
        end
      EOS
    end

    # Not support
    xparse_by "a = 42 if a.nil?" do
      it { is_expected.to unparsed(<<~EOS.chomp) }
        if a.nil?()
          (a = 42)
        end
      EOS
    end
  end

  describe "NODE_UNLESS" do
    parse_by "unless x == 1 then hoge end" do
      it { is_expected.to unparsed(<<~EOS.chomp) }
        unless (x == 1)
          hoge
        end
      EOS
      it { is_expected.to type_of :UNLESS }
    end
    parse_by "unless x == 1 then hoge else foo end" do
      it { is_expected.to unparsed(<<~EOS.chomp) }
        unless (x == 1)
          hoge
        else
          foo
        end
      EOS
    end
    parse_by "hoge unless x == 1" do
      it { is_expected.to unparsed(<<~EOS.chomp) }
        unless (x == 1)
          hoge
        end
      EOS
    end
  end

  describe "NODE_CASE" do
    parse_by "case x; when 1; foo; when 2; bar; else baz; end" do
      it { is_expected.to unparsed(<<~EOS.chomp) }
        case x
        when 1
          foo
        when 2
          bar
        else
          baz
        end
      EOS
      it { is_expected.to type_of :CASE }
    end
  end

  describe "NODE_CASE2" do
    parse_by "case; when 1; foo; when 2; bar; else baz; end" do
      it { is_expected.to unparsed(<<~EOS.chomp) }
        case
        when 1
          foo
        when 2
          bar
        else
          baz
        end
      EOS
      it { is_expected.to type_of :CASE2 }
    end
  end

  xdescribe "NODE_CASE3" do
    # Ruby 2.7
    # :TODO:
  end

  describe "NODE_WHEN" do
    # Test with NODE_CASE
  end

  xdescribe "NODE_IN" do
    # Ruby 2.7
    # :TODO:
  end

  describe "NODE_WHILE" do
    parse_by "while x == 1; foo; end" do
      it { is_expected.to unparsed(<<~EOS.chomp) }
        while (x == 1)
          foo
        end
      EOS
      it { is_expected.to type_of :WHILE }
    end
    parse_by "foo while x == 1" do
      it { is_expected.to unparsed(<<~EOS.chomp) }
        while (x == 1)
          foo
        end
      EOS
    end

    context "by 2.7.0", ruby_version: "2.7.0"... do
      parse_by "begin foo end while x == 1" do
        it { is_expected.to unparsed(<<~EOS.chomp) }
          begin
            foo
          end while (x == 1)
        EOS
      end
    end
  end

  describe "NODE_UNTIL" do
    parse_by "until x == 1; foo; end" do
      it { is_expected.to unparsed(<<~EOS.chomp) }
        until (x == 1)
          foo
        end
      EOS
      it { is_expected.to type_of :UNTIL }
    end
    parse_by "foo until x == 1" do
      it { is_expected.to unparsed(<<~EOS.chomp) }
        until (x == 1)
          foo
        end
      EOS
    end

    context "by 2.7.0", ruby_version: "2.7.0"... do
      parse_by "begin foo end until x == 1" do
        it { is_expected.to unparsed(<<~EOS.chomp) }
          begin
            foo
          end until (x == 1)
        EOS
      end
    end
  end

  describe "NODE_ITER" do
    parse_by "3.times { foo }" do
      it { is_expected.to unparsed "3.times() { foo }" }
      it { is_expected.to type_of :ITER }
    end
  end

  describe "NODE_FOR" do
    parse_by "for i in 1..3 do foo end" do
      it { is_expected.to unparsed(<<~EOS.chomp) }
        for i in (1..3) do
          foo
        end
      EOS
      it { is_expected.to type_of :FOR }
    end
    parse_by "for i in 1..3 do i end" do
      it { is_expected.to unparsed(<<~EOS.chomp) }
        for i in (1..3) do
          i
        end
      EOS
    end
    parse_by "for i in 1..3 do func(42) end" do
      it { is_expected.to unparsed(<<~EOS.chomp) }
        for i in (1..3) do
          func(42)
        end
      EOS
    end
  end

  describe "NODE_FOR_MASGN" do
    parse_by "for x, y in 1..3 do foo end" do
      it { is_expected.to unparsed(<<~EOS.chomp) }
        for (x, y, ) in (1..3) do
          foo
        end
      EOS
    end
    parse_by "for * in 1..3 do foo end" do
      it { is_expected.to unparsed(<<~EOS.chomp) }
        for (*) in (1..3) do
          foo
        end
      EOS
    end
  end

  describe "NODE_BREAK" do
    parse_by "break 1" do
      it { is_expected.to unparsed "break 1" }
      it { is_expected.to type_of :BREAK }
    end
  end

  describe "NODE_NEXT" do
    parse_by "next 1" do
      it { is_expected.to unparsed "next 1" }
      it { is_expected.to type_of :NEXT }
    end
  end

  describe "NODE_RETURN" do
    parse_by "return 1" do
      it { is_expected.to unparsed "(return 1)" }
      it { is_expected.to type_of :RETURN }
    end
    parse_by "return []" do
      it { is_expected.to unparsed "(return [])" }
    end
    parse_by "return [1, 2, 3]" do
      it { is_expected.to unparsed "(return [1, 2, 3])" }
    end
    parse_by "foo and return 1" do
      it { is_expected.to unparsed "(foo && (return 1))" }
    end
    parse_by "foo and (return 1)" do
      it { is_expected.to unparsed "(foo && (return 1))" }
    end
  end

  describe "NODE_REDO" do
    parse_by "redo" do
      it { is_expected.to unparsed "redo" }
      it { is_expected.to type_of :REDO }
    end
  end

  describe "NODE_RETRY" do
    parse_by "retry" do
      it { is_expected.to unparsed "retry" }
      it { is_expected.to type_of :RETRY }
    end
  end

  describe "NODE_BEGIN" do
    parse_by "begin; end" do
      it { is_expected.to unparsed "" }
      it { is_expected.to type_of :BEGIN }
    end
    parse_by "begin; 1; end" do
      it { is_expected.to unparsed "begin; 1; end" }
    end
    parse_by "begin; 1; end; 1" do
      it { is_expected.to unparsed "begin; 1; 1; end" }
    end
    context "by 2.6.0", ruby_version: "2.6.0"..."2.7.0" do
      parse_by "a = begin; foo; bar; hoge end" do
        it { is_expected.to unparsed "(a = begin; foo; bar; hoge; end)" }
      end
    end
    context "by 3.0.0", ruby_version: "3.0.0"... do
      parse_by "a = begin; foo; bar; hoge end" do
        it { is_expected.to unparsed "(a = begin\n  begin; foo; bar; hoge; end\nend)" }
      end
    end
    parse_by "begin hoge; end" do
      it { is_expected.to unparsed "hoge" }
    end
    parse_by "begin hoge; foo; end" do
      it { is_expected.to unparsed "begin hoge; foo; end" }
    end
    context "by 2.6.0", ruby_version: "2.6.0"..."2.7.0" do
      parse_by "a = begin foo; bar; hoge end" do
        it { is_expected.to unparsed "(a = begin foo; bar; hoge; end)" }
      end
    end
    context "by 3.0.0", ruby_version: "3.0.0"... do
      parse_by "a = begin foo; bar; hoge end" do
        it { is_expected.to unparsed "(a = begin\n  begin foo; bar; hoge; end\nend)" }
      end
    end
    parse_by "BEGIN { foo }" do
      it { is_expected.to unparsed "BEGIN { foo }" }
    end
    parse_by "BEGIN { foo; bar }" do
      it { is_expected.to unparsed "BEGIN { begin foo; bar; end }" }
    end
  end

  describe "NODE_RESCUE" do
    parse_by "begin; foo; rescue; bar; else; baz; end" do
      it { is_expected.to unparsed(<<~EOS.chomp) }
        begin
          begin; foo; end
        rescue ; bar
        else
          begin; baz; end
        end
      EOS
      it { is_expected.to type_of :RESCUE }
    end
    parse_by "begin; foo; hoge; rescue; bar; piyo; else; baz; foo; end" do
      it { is_expected.to unparsed(<<~EOS.chomp) }
        begin
          begin; foo; hoge; end
        rescue ;begin bar; piyo; end
        else
          begin; baz; foo; end
        end
      EOS
      it { is_expected.to type_of :RESCUE }
    end
    parse_by <<~EOS do
      begin
        foo
      rescue
          bar
      else
        baz
      end
    EOS
      it { is_expected.to unparsed(<<~EOS.chomp) }
        begin
          foo
        rescue ; bar
        else
          baz
        end
      EOS
    end
    parse_by "begin; foo; rescue => e; bar; else; baz; end" do
      it { is_expected.to unparsed(<<~EOS.chomp) }
        begin
          begin; foo; end
        rescue => e; bar
        else
          begin; baz; end
        end
      EOS
    end
    parse_by "begin; foo; rescue => e; begin; hoge; bar; end end" do
      it { is_expected.to unparsed(<<~EOS.chomp) }
        begin
          begin; foo; end
        rescue => e; ; hoge; bar
        end
      EOS
    end
    parse_by "begin; foo; rescue e; bar; else; baz; end" do
      it { is_expected.to unparsed(<<~EOS.chomp) }
        begin
          begin; foo; end
        rescue e; bar
        else
          begin; baz; end
        end
      EOS
    end
    parse_by "begin; foo; rescue e, e2; bar; else; baz; end" do
      it { is_expected.to unparsed(<<~EOS.chomp) }
        begin
          begin; foo; end
        rescue e, e2; bar
        else
          begin; baz; end
        end
      EOS
    end
    parse_by "begin; foo; rescue; bar; end" do
      it { is_expected.to unparsed(<<~EOS.chomp) }
        begin
          begin; foo; end
        rescue ; bar
        end
      EOS
    end
    parse_by "def hoge; rescue; end" do
      it { is_expected.to unparsed("def hoge()\n  begin\n  \nrescue ; \nend\nend") }
    end
  end

  describe "NODE_RESBODY" do
    parse_by <<~EOS do
      begin
        foo
      rescue
        bar
      end
    EOS
      it { is_expected.to unparsed(<<~EOS.chomp) }
        begin
          foo
        rescue ; bar
        end
      EOS
    end
    parse_by <<~EOS do
      begin
        foo
      rescue
        bar
        hoge
      end
    EOS
      it { is_expected.to unparsed(<<~EOS.chomp) }
        begin
          foo
        rescue ;begin bar; hoge; end
        end
      EOS
    end
    parse_by <<~EOS do
      begin
        foo
      rescue e
        bar
        hoge
      end
    EOS
      it { is_expected.to unparsed(<<~EOS.chomp) }
        begin
          foo
        rescue e;begin bar; hoge; end
        end
      EOS
    end
    parse_by <<~EOS do
      begin
        foo
      rescue e1, e2
        bar
        hoge
      end
    EOS
      it { is_expected.to unparsed(<<~EOS.chomp) }
        begin
          foo
        rescue e1, e2;begin bar; hoge; end
        end
      EOS
    end
    parse_by <<~EOS do
      begin
        foo
      rescue e
        bar
      end
    EOS
      it { is_expected.to unparsed(<<~EOS.chomp) }
        begin
          foo
        rescue e; bar
        end
      EOS
    end
    parse_by <<~EOS do
      begin
        foo
      rescue => e
        bar
      end
    EOS
      it { is_expected.to unparsed(<<~EOS.chomp) }
        begin
          foo
        rescue => e; bar
        end
      EOS
    end
  end

  describe "NODE_ENSURE" do
    parse_by "begin; foo; ensure; bar; end" do
      it { is_expected.to unparsed(<<~EOS.chomp) }
        begin
          begin; foo; end
        ensure
          begin; bar; end
        end
      EOS
      it { is_expected.to type_of :ENSURE }
    end
    parse_by "begin; foo; rescue => e; bar; ensure; baz; end" do
      it { is_expected.to unparsed(<<~EOS.chomp) }
        begin
          begin
          begin; foo; end
        rescue => e; bar
        end
        ensure
          begin; baz; end
        end
      EOS
    end
    parse_by "def hoge(); foo; ensure; bar; end" do
      it { is_expected.to unparsed(<<~EOS.chomp) }
        def hoge()
          begin
          begin; foo; end
        ensure
          begin; bar; end
        end
        end
      EOS
    end
  end

  describe "NODE_AND" do
    parse_by "foo && bar" do
      it { is_expected.to unparsed "(foo && bar)" }
      it { is_expected.to type_of :AND }
    end
    parse_by "foo and bar" do
      it { is_expected.to unparsed "(foo && bar)" }
      it { is_expected.to type_of :AND }
    end
    parse_by "foo && bar && hoge" do
      it { is_expected.to unparsed "(foo && bar && hoge)" }
    end
    parse_by "foo and bar && hoge" do
      it { is_expected.to unparsed "(foo && bar && hoge)" }
    end
    parse_by "foo && bar and hoge" do
      it { is_expected.to unparsed "(foo && bar && hoge)" }
    end
    parse_by "foo and bar and hoge" do
      it { is_expected.to unparsed "(foo && bar && hoge)" }
    end
    parse_by "x = foo && bar" do
      it { is_expected.to unparsed "(x = (foo && bar))" }
    end
    parse_by "x = foo && bar and hoge" do
      it { is_expected.to unparsed "((x = (foo && bar)) && hoge)" }
    end
    parse_by "x = foo and bar && hoge" do
      it { is_expected.to unparsed "((x = foo) && bar && hoge)" }
    end
    parse_by "x = (foo and bar) && hoge" do
      it { is_expected.to unparsed "(x = (foo && bar && hoge))" }
    end
    parse_by "x = (foo and bar) and hoge" do
      it { is_expected.to unparsed "((x = (foo && bar)) && hoge)" }
    end
  end

  describe "NODE_OR" do
    parse_by "foo || bar" do
      it { is_expected.to unparsed "(foo || bar)" }
      it { is_expected.to type_of :OR }
    end
    parse_by "foo or bar" do
      it { is_expected.to unparsed "(foo || bar)" }
      it { is_expected.to type_of :OR }
    end
    parse_by "foo || bar || hoge" do
      it { is_expected.to unparsed "(foo || bar || hoge)" }
    end
    parse_by "foo or bar || hoge" do
      it { is_expected.to unparsed "(foo || bar || hoge)" }
    end
    parse_by "foo || bar or hoge" do
      it { is_expected.to unparsed "(foo || bar || hoge)" }
    end
    parse_by "foo or bar or hoge" do
      it { is_expected.to unparsed "(foo || bar || hoge)" }
    end
    parse_by "x = foo || bar" do
      it { is_expected.to unparsed "(x = (foo || bar))" }
    end
    parse_by "x = foo || bar or hoge" do
      it { is_expected.to unparsed "((x = (foo || bar)) || hoge)" }
    end
    parse_by "x = foo or bar || hoge" do
      it { is_expected.to unparsed "((x = foo) || bar || hoge)" }
    end
    parse_by "x = (foo or bar) || hoge" do
      it { is_expected.to unparsed "(x = (foo || bar || hoge))" }
    end
    parse_by "x = (foo or bar) or hoge" do
      it { is_expected.to unparsed "((x = (foo || bar)) || hoge)" }
    end
  end

  describe "NODE_MASGN" do
    parse_by "a, = foo" do
      it { is_expected.to unparsed "(a, ) = foo" }
      it { is_expected.to type_of :MASGN }
    end
    parse_by "a, b = foo" do
      it { is_expected.to unparsed "(a, b, ) = foo" }
      it { is_expected.to type_of :MASGN }
    end
    parse_by "a, b, = foo" do
      it { is_expected.to unparsed "(a, b, ) = foo" }
      it { is_expected.to type_of :MASGN }
    end
    parse_by "a, b = foo, hoge" do
      it { is_expected.to unparsed "(a, b, ) = [foo, hoge]" }
    end
    parse_by "(a, b) = foo" do
      it { is_expected.to unparsed "(a, b, ) = foo" }
    end
    parse_by "(a, b), = foo" do
      it { is_expected.to unparsed "((a, b, ), ) = foo" }
    end
    parse_by "(a, b), c = foo" do
      it { is_expected.to unparsed "((a, b, ), c, ) = foo" }
    end
    parse_by "a, (b, c) = foo" do
      it { is_expected.to unparsed "(a, (b, c, ), ) = foo" }
    end
    parse_by "(a, b), (c, d) = foo" do
      it { is_expected.to unparsed "((a, b, ), (c, d, ), ) = foo" }
    end
    parse_by "(a, b), (c, *d) = foo" do
      it { is_expected.to unparsed "((a, b, ), (c, *d), ) = foo" }
    end
    parse_by "(a, *b), (c, *d) = foo" do
      it { is_expected.to unparsed "((a, *b), (c, *d), ) = foo" }
    end
    parse_by "(a, b), (c, *) = foo" do
      it { is_expected.to unparsed "((a, b, ), (c, *), ) = foo" }
    end
    parse_by "* = foo" do
      it { is_expected.to unparsed "(*) = foo" }
    end
    parse_by "a, b, * = foo" do
      it { is_expected.to unparsed "(a, b, *) = foo" }
    end
    parse_by "a, b, *c = foo" do
      it { is_expected.to unparsed "(a, b, *c) = foo" }
    end
    parse_by "((a, b), c) = foo" do
      it { is_expected.to unparsed "((a, b, ), c, ) = foo" }
    end
    xparse_by "a, *b, c = foo"

    context "block arguments" do
      parse_by "proc { |(a)| }" do
        it { is_expected.to unparsed "proc() { |(a)|  }" }
      end
      parse_by "proc { |(a, *)| }" do
        it { is_expected.to unparsed "proc() { |(a, *)|  }" }
      end
      parse_by "proc { |((a))| }" do
        it { is_expected.to unparsed "proc() { |((a))|  }" }
      end
      parse_by "proc { |((a, *))| }" do
        it { is_expected.to unparsed "proc() { |((a, *))|  }" }
      end
      parse_by "proc { |((a), *)| }" do
        it { is_expected.to unparsed "proc() { |((a), *)|  }" }
      end
      parse_by "proc { |((a, *), *)| }" do
        it { is_expected.to unparsed "proc() { |((a, *), *)|  }" }
      end
      parse_by "proc { |(((a)))| }" do
        it { is_expected.to unparsed "proc() { |(((a)))|  }" }
      end
      parse_by "proc { |((a), b)| }" do
        it { is_expected.to unparsed "proc() { |((a), b)|  }" }
      end
    end
  end

  describe "NODE_LASGN" do
    parse_by "x = foo" do
      it { is_expected.to unparsed "(x = foo)" }
      it { is_expected.to type_of :LASGN }
    end
    parse_by "a = 1, b = 2" do
      it { is_expected.to unparsed "(a = [1, (b = 2)])" }
    end
    parse_by "a = 1, b" do
      it { is_expected.to unparsed "(a = [1, b])" }
    end
    parse_by "a = [1, b]" do
      it { is_expected.to unparsed "(a = [1, b])" }
    end
    parse_by "a = [1, b].min" do
      it { is_expected.to unparsed "(a = [1, b].min())" }
    end
    parse_by "a = 1, b" do
      it { is_expected.to unparsed "(a = [1, b])" }
    end
    parse_by "x += y" do
      it { is_expected.to unparsed "(x = x.+(y))" }
    end
  end

  describe "NODE_DASGN" do
    parse_by "x = nil; 1.times { x = foo }" do
      it { is_expected.to unparsed "begin (x = nil); 1.times() { (x = foo) }; end" }
    end
    parse_by "x = nil; 1.times { x = foo and hoge }" do
      it { is_expected.to unparsed "begin (x = nil); 1.times() { ((x = foo) && hoge) }; end" }
    end
    parse_by "begin (x = 42); x; end" do
      it { is_expected.to unparsed "begin (x = 42); x; end" }
    end
  end

  describe "NODE_DASGN_CURR" do
    parse_by "1.times { x = foo }" do
      it { is_expected.to unparsed "1.times() { (x = foo) }" }
    end
    parse_by "1.times { x = foo and hoge }" do
      it { is_expected.to unparsed "1.times() { ((x = foo) && hoge) }" }
    end
  end

  describe "NODE_IASGN" do
    parse_by "@x = foo" do
      it { is_expected.to unparsed "(@x = foo)" }
      it { is_expected.to type_of :IASGN }
    end
    parse_by "@x = foo && hoge" do
      it { is_expected.to unparsed "(@x = (foo && hoge))" }
    end
    parse_by "@x = foo and hoge" do
      it { is_expected.to unparsed "((@x = foo) && hoge)" }
    end
    parse_by "1.times { @x = foo }" do
      it { is_expected.to unparsed "1.times() { (@x = foo) }" }
    end
    parse_by "1.times { @x = foo and hoge }" do
      it { is_expected.to unparsed "1.times() { ((@x = foo) && hoge) }" }
    end
    parse_by "hoge(@a = 1) { @a, b = c }" do
      it { is_expected.to unparsed "hoge((@a = 1)) { (@a, b, ) = c }" }
    end
  end

  describe "NODE_CVASGN" do
    parse_by "@@x = foo" do
      it { is_expected.to unparsed "(@@x = foo)" }
      it { is_expected.to type_of :CVASGN }
    end
    parse_by "@@x = foo && hoge" do
      it { is_expected.to unparsed "(@@x = (foo && hoge))" }
    end
    parse_by "@@x = foo and hoge" do
      it { is_expected.to unparsed "((@@x = foo) && hoge)" }
    end
    parse_by "1.times { @@x = foo }" do
      it { is_expected.to unparsed "1.times() { (@@x = foo) }" }
    end
    parse_by "1.times { @@x = foo and hoge }" do
      it { is_expected.to unparsed "1.times() { ((@@x = foo) && hoge) }" }
    end
    parse_by "hoge(@@a = 1) { @@a, b = c }" do
      it { is_expected.to unparsed "hoge((@@a = 1)) { (@@a, b, ) = c }" }
    end
  end

  describe "NODE_GASGN" do
    parse_by "$x = foo" do
      it { is_expected.to unparsed "($x = foo)" }
      it { is_expected.to type_of :GASGN }
    end
    parse_by "$x = foo && hoge" do
      it { is_expected.to unparsed "($x = (foo && hoge))" }
    end
    parse_by "$x = foo and hoge" do
      it { is_expected.to unparsed "(($x = foo) && hoge)" }
    end
    parse_by "1.times { $x = foo }" do
      it { is_expected.to unparsed "1.times() { ($x = foo) }" }
    end
    parse_by "1.times { $x = foo and hoge }" do
      it { is_expected.to unparsed "1.times() { (($x = foo) && hoge) }" }
    end
    parse_by "hoge($a = 1) { $a, b = c }" do
      it { is_expected.to unparsed "hoge(($a = 1)) { ($a, b, ) = c }" }
    end
  end

  describe "NODE_CDECL" do
    parse_by "X = foo" do
      it { is_expected.to unparsed "(X = foo)" }
      it { is_expected.to type_of :CDECL }
    end
    parse_by "::X = foo" do
      it { is_expected.to unparsed "(::X = foo)" }
    end
    parse_by "X::Y = foo" do
      it { is_expected.to unparsed "(X::Y = foo)" }
    end
    parse_by "::X::Y = foo" do
      it { is_expected.to unparsed "(::X::Y = foo)" }
    end
    parse_by "X = foo && hoge" do
      it { is_expected.to unparsed "(X = (foo && hoge))" }
    end
    parse_by "X::Y = foo && hoge" do
      it { is_expected.to unparsed "(X::Y = (foo && hoge))" }
    end
    parse_by "X = foo and hoge" do
      it { is_expected.to unparsed "((X = foo) && hoge)" }
    end
    parse_by "X::Y = foo and hoge" do
      it { is_expected.to unparsed "((X::Y = foo) && hoge)" }
    end
    parse_by "1.times { X = foo }" do
      it { is_expected.to unparsed "1.times() { (X = foo) }" }
    end
    parse_by "1.times { X = foo and hoge }" do
      it { is_expected.to unparsed "1.times() { ((X = foo) && hoge) }" }
    end
    parse_by "hoge(A = 1) { A, b = c }" do
      it { is_expected.to unparsed "hoge((A = 1)) { (A, b, ) = c }" }
    end
    parse_by "hoge(A::B = 1) { A::B, b = c }" do
      it { is_expected.to unparsed "hoge((A::B = 1)) { (A::B, b, ) = c }" }
    end
    parse_by "hoge(A::B::C = 1) { A::B::C, b = c }" do
      it { is_expected.to unparsed "hoge((A::B::C = 1)) { (A::B::C, b, ) = c }" }
    end
  end

  describe "NODE_OP_ASGN1" do
    parse_by "ary[1] += foo" do
      it { is_expected.to unparsed "(ary[1] += foo)" }
      it { is_expected.to type_of :OP_ASGN1 }
    end
    parse_by "ary[1] += foo.bar" do
      it { is_expected.to unparsed "(ary[1] += foo.bar())" }
    end
    parse_by "ary[1] += foo + bar" do
      it { is_expected.to unparsed "(ary[1] += (foo + bar))" }
    end
    parse_by "ary[1] += foo && bar" do
      it { is_expected.to unparsed "(ary[1] += (foo && bar))" }
    end
    parse_by "ary[1] += foo and bar" do
      it { is_expected.to unparsed "((ary[1] += foo) && bar)" }
    end
    parse_by "ary[1 + 2] += foo" do
      it { is_expected.to unparsed "(ary[(1 + 2)] += foo)" }
    end
    parse_by "(ary.foo)[1 + 2] += hoge" do
      it { is_expected.to unparsed "(ary.foo()[(1 + 2)] += hoge)" }
    end
    parse_by "(ary.foo(1))[1 + 2] += hoge" do
      it { is_expected.to unparsed "(ary.foo(1)[(1 + 2)] += hoge)" }
    end
  end

  describe "NODE_OP_ASGN2" do
    parse_by "struct.field += foo", ruby_version: "2.7.2"... do
      it { is_expected.to unparsed "struct.field += foo" }
      it { is_expected.to type_of :OP_ASGN2 }
    end
  end

  describe "NODE_OP_ASGN_AND" do
    parse_by "hoge &&= foo" do
      it { is_expected.to unparsed "(hoge &&= foo)" }
    end
  end

  describe "NODE_OP_ASGN_OR" do
    parse_by "hoge ||= foo" do
      it { is_expected.to unparsed "(hoge ||= foo)" }
    end
  end

  describe "NODE_OP_CDECL" do
    parse_by "::B ||= 1" do
      it { is_expected.to unparsed "(::B ||= 1)" }
      it { is_expected.to type_of :OP_CDECL }
    end
    parse_by "A::B ||= 1" do
      it { is_expected.to unparsed "(A::B ||= 1)" }
    end
    parse_by "A::B ||= 1 + 2" do
      it { is_expected.to unparsed "(A::B ||= (1 + 2))" }
    end
    parse_by "A::B ||= 1 && 2" do
      it { is_expected.to unparsed "(A::B ||= (1 && 2))" }
    end
    parse_by "A::B ||= 1 and 2" do
      it { is_expected.to unparsed "((A::B ||= 1) && 2)" }
    end
    parse_by "A::B ||= 1 || 2" do
      it { is_expected.to unparsed "(A::B ||= (1 || 2))" }
    end
    parse_by "A::B ||= 1 or 2" do
      it { is_expected.to unparsed "((A::B ||= 1) || 2)" }
    end
    parse_by "A::B &&= 1" do
      it { is_expected.to unparsed "(A::B &&= 1)" }
    end
    parse_by "A::B &&= 1 + 2" do
      it { is_expected.to unparsed "(A::B &&= (1 + 2))" }
    end
    parse_by "A::B &&= 1 + 2" do
      it { is_expected.to unparsed "(A::B &&= (1 + 2))" }
    end
    parse_by "A::B &&= 1 && 2" do
      it { is_expected.to unparsed "(A::B &&= (1 && 2))" }
    end
    parse_by "A::B &&= 1 and 2" do
      it { is_expected.to unparsed "((A::B &&= 1) && 2)" }
    end
    parse_by "A::B &&= 1 || 2" do
      it { is_expected.to unparsed "(A::B &&= (1 || 2))" }
    end
    parse_by "A::B &&= 1 or 2" do
      it { is_expected.to unparsed "((A::B &&= 1) || 2)" }
    end
  end

  describe "NODE_CALL" do
    parse_by "obj.foo(1)" do
      it { is_expected.to unparsed "obj.foo(1)" }
      it { is_expected.to type_of :CALL }
    end
    parse_by "obj.foo(1, 2, 3)" do
      it { is_expected.to unparsed "obj.foo(1, 2, 3)" }
    end
    parse_by "obj.foo(1, [2, 3])" do
      it { is_expected.to unparsed "obj.foo(1, [2, 3])" }
    end
    parse_by "obj.foo(1).bar" do
      it { is_expected.to unparsed "obj.foo(1).bar()" }
    end
    parse_by "ary[0]" do
      it { is_expected.to unparsed "ary.[](0)" }
    end
    parse_by "1.+ 1" do
      it { is_expected.to unparsed "1.+(1)" }
    end
    parse_by "X::Y()" do
      it { is_expected.to unparsed "X.Y()" }
    end
    parse_by "X.Y" do
      it { is_expected.to unparsed "X.Y()" }
    end
    parse_by "hoge.!" do
      it { is_expected.to unparsed "hoge.!()" }
    end
    parse_by "hoge.+@" do
      it { is_expected.to unparsed "hoge.+@()" }
    end
    parse_by "hoge.[]=foo" do
      it { is_expected.to unparsed "hoge.[]=(foo)" }
    end
  end

  describe "NODE_OPCALL" do
    parse_by "1 + 1" do
      it { is_expected.to unparsed "(1 + 1)" }
      it { is_expected.to type_of :OPCALL }
    end
    parse_by "1 == 1" do
      it { is_expected.to unparsed "(1 == 1)" }
    end
    parse_by "1 + 2 + 3" do
      it { is_expected.to unparsed "((1 + 2) + 3)" }
    end
    parse_by "!foo" do
      it { is_expected.to unparsed "(!foo)" }
    end
    parse_by "+foo" do
      it { is_expected.to unparsed "(+foo)" }
    end
    parse_by "~foo" do
      it { is_expected.to unparsed "(~foo)" }
    end
  end

  describe "NODE_FCALL" do
    parse_by "func(1)" do
      it { is_expected.to unparsed "func(1)" }
      it { is_expected.to type_of :FCALL }
    end
    parse_by "func(1, 2, 3)" do
      it { is_expected.to unparsed "func(1, 2, 3)" }
      it { is_expected.to type_of :FCALL }
    end
    parse_by "func(1, [2, 3])" do
      it { is_expected.to unparsed "func(1, [2, 3])" }
      it { is_expected.to type_of :FCALL }
    end
    parse_by "foo(arg, *[1, 2, 3])" do
      it { is_expected.to unparsed "foo(arg, 1, 2, 3)" }
      it { is_expected.to type_of :FCALL }
    end
    parse_by "X(1)" do
      it { is_expected.to unparsed "X(1)" }
    end
    parse_by "X 1" do
      it { is_expected.to unparsed "X(1)" }
    end
    parse_by "obj[:type]" do
      it { is_expected.to unparsed "obj.[](:type)" }
    end
    parse_by "self[:type]" do
      it { is_expected.to unparsed "self[:type]" }
    end
  end

  describe "NODE_VCALL" do
    parse_by "hoge" do
      it { is_expected.to unparsed "hoge" }
      it { is_expected.to type_of :VCALL }
    end
    parse_by "hoge;" do
      it { is_expected.to unparsed "hoge" }
    end
    parse_by "hoge\n" do
      it { is_expected.to unparsed "hoge" }
    end
  end

  describe "NODE_QCALL" do
    parse_by "obj&.hoge(0)" do
      it { is_expected.to unparsed "obj&.hoge(0)" }
      it { is_expected.to type_of :QCALL }
    end
    parse_by "obj&.hoge(0, 1, 2)" do
      it { is_expected.to unparsed "obj&.hoge(0, 1, 2)" }
      it { is_expected.to type_of :QCALL }
    end
  end

  describe "NODE_SUPER" do
    parse_by "super()" do
      it { is_expected.to unparsed "super()" }
      it { is_expected.to type_of :SUPER }
    end
    parse_by "super 1" do
      it { is_expected.to unparsed "super(1)" }
    end
    parse_by "super 1, 2" do
      it { is_expected.to unparsed "super(1, 2)" }
    end
  end

  describe "NODE_ZSUPER" do
    parse_by "super" do
      it { is_expected.to unparsed "super" }
      it { is_expected.to type_of :ZSUPER }
    end
  end

  describe "NODE_ARRAY" do
    parse_by "[1, 2, 3]" do
      it { is_expected.to unparsed "[1, 2, 3]" }
      context "by 2.6.0", ruby_version: "2.6.0"..."2.7.0" do
        it { is_expected.to type_of :ARRAY }
      end
      context "by 2.7.0", ruby_version: "2.7.0"... do
        it { is_expected.to type_of :LIST }
      end
    end
    parse_by "[[1]]" do
      it { is_expected.to unparsed "[[1]]" }
    end
    parse_by "[1, [2, [3]]]" do
      it { is_expected.to unparsed "[1, [2, [3]]]" }
    end
    parse_by "func [1, [2, [3]]]" do
      it { is_expected.to unparsed "func([1, [2, [3]]])" }
    end
    parse_by "func[1]" do
      it { is_expected.to unparsed "func.[](1)" }
    end
    parse_by "[1 + 2]" do
      it { is_expected.to unparsed "[(1 + 2)]" }
    end
    parse_by "[func(1 + 2)]" do
      it { is_expected.to unparsed "[func((1 + 2))]" }
    end
  end

  describe "NODE_VALUES" do
    parse_by "return 1, 2, 3" do
      it { is_expected.to unparsed "(return 1, 2, 3)" }
      it { is_expected.to children_type_of :VALUES }
    end
    parse_by "return 1, [], [2, 3]" do
      it { is_expected.to unparsed "(return 1, [], [2, 3])" }
    end
    parse_by "foo and return 1, 2" do
      it { is_expected.to unparsed "(foo && (return 1, 2))" }
    end
    parse_by "foo and (return 1, 2)" do
      it { is_expected.to unparsed "(foo && (return 1, 2))" }
    end
  end

  describe "NODE_ZARRAY", ruby_version: "2.6.0"..."2.7.0" do
    parse_by "[]" do
      it { is_expected.to unparsed "[]" }
      it { is_expected.to type_of :ZARRAY }
    end
    parse_by "[[]]" do
      it { is_expected.to unparsed "[[]]" }
    end
    parse_by "[1, []]" do
      it { is_expected.to unparsed "[1, []]" }
    end
    parse_by "func []" do
      it { is_expected.to unparsed "func([])" }
    end
  end

  describe "NODE_ZLIST", ruby_version: "2.7.0"... do
    parse_by "[]" do
      it { is_expected.to unparsed "[]" }
      it { is_expected.to type_of :ZLIST }
    end
    parse_by "[[]]" do
      it { is_expected.to unparsed "[[]]" }
    end
    parse_by "[1, []]" do
      it { is_expected.to unparsed "[1, []]" }
    end
    parse_by "func []" do
      it { is_expected.to unparsed "func([])" }
    end
  end

  describe "NODE_HASH" do
    parse_by "{ 1 => 2, 3 => 4, hoge => 5 }" do
      it { is_expected.to unparsed "{ 1 => 2, 3 => 4, hoge => 5 }" }
      it { is_expected.to type_of :HASH }
    end
    parse_by "{ hoge: foo, bar: piyo }" do
      it { is_expected.to unparsed "{ :hoge => foo, :bar => piyo }" }
    end
    parse_by "{}" do
      it { is_expected.to unparsed "{}" }
    end
    parse_by "foo a: 1, b: 2" do
      it { is_expected.to unparsed "foo({ :a => 1, :b => 2 })" }
    end
    parse_by "foo hoge, a: 1, b: 2" do
      it { is_expected.to unparsed "foo(hoge, { :a => 1, :b => 2 })" }
    end
    parse_by "foo **kwd" do
      it { is_expected.to unparsed "foo(**kwd)" }
    end
    parse_by "foo(a, *b, **c)" do
      it { is_expected.to unparsed "foo(a, *b, **c)" }
    end
    parse_by "foo(**hoge.bar)" do
      it { is_expected.to unparsed "foo(**hoge.bar())" }
    end
  end

  describe "NODE_YIELD" do
    parse_by "yield" do
      it { is_expected.to unparsed "yield()" }
      it { is_expected.to type_of :YIELD }
    end
    parse_by "yield 1, 2" do
      it { is_expected.to unparsed "yield(1, 2)" }
    end
    parse_by "yield []" do
      it { is_expected.to unparsed "yield([])" }
    end
    parse_by "yield [1, 2]" do
      it { is_expected.to unparsed "yield([1, 2])" }
    end
  end

  describe "NODE_LVAR" do
    parse_by "x = 42; x" do
      it { is_expected.to unparsed "begin (x = 42); x; end" }
    end
  end

  describe "NODE_DVAR" do
    parse_by "1.times { x = 1; x }" do
      it { is_expected.to unparsed "1.times() { begin (x = 1); x; end }" }
    end
  end

  describe "NODE_IVAR" do
    parse_by "@a" do
      it { is_expected.to unparsed "@a" }
      it { is_expected.to type_of :IVAR }
    end
    parse_by "@a.foo" do
      it { is_expected.to unparsed "@a.foo()" }
    end
  end

  describe "NODE_CONST" do
    parse_by "X" do
      it { is_expected.to unparsed "X" }
      it { is_expected.to type_of :CONST }
    end
  end

  describe "NODE_CVAR" do
    parse_by "@@a" do
      it { is_expected.to unparsed "@@a" }
      it { is_expected.to type_of :CVAR }
    end
    parse_by "@@a.foo" do
      it { is_expected.to unparsed "@@a.foo()" }
    end
  end

  describe "NODE_GVAR" do
    parse_by "$a" do
      it { is_expected.to unparsed "$a" }
      it { is_expected.to type_of :GVAR }
    end
    parse_by "$a.foo" do
      it { is_expected.to unparsed "$a.foo()" }
    end
  end

  describe "NODE_NTH_REF" do
    parse_by "$1" do
      it { is_expected.to unparsed "$1" }
      it { is_expected.to type_of :NTH_REF }
    end
  end

  describe "NODE_BACK_REF" do
    parse_by "$&" do
      it { is_expected.to unparsed "$&" }
      it { is_expected.to type_of :BACK_REF }
    end
    parse_by "$`" do
      it { is_expected.to unparsed "$`" }
      it { is_expected.to type_of :BACK_REF }
    end
    parse_by "$'" do
      it { is_expected.to unparsed "$'" }
      it { is_expected.to type_of :BACK_REF }
    end
    parse_by "$+" do
      it { is_expected.to unparsed "$+" }
      it { is_expected.to type_of :BACK_REF }
    end
  end

  describe "NODE_MATCH" do
    # warning: (none):1: warning: regex literal in condition
    parse_by "if /foo/ then foo end" do
      it { is_expected.to unparsed(<<~EOS.chomp) }
        if /foo/
          foo
        end
      EOS
    end
  end

  describe "NODE_MATCH2" do
    parse_by "/foo/ =~ 'foo'" do
      it { is_expected.to unparsed "/foo/ =~ \"foo\"" }
    end
  end

  describe "NODE_MATCH3" do
    parse_by "'foo' =~ /foo/" do
      it { is_expected.to unparsed "\"foo\" =~ /foo/" }
    end
  end

  describe "NODE_LIT" do
    parse_by "1" do
      it { is_expected.to unparsed "1" }
      it { is_expected.to type_of :LIT }
    end
    parse_by "3.14" do
      it { is_expected.to unparsed "3.14" }
    end
    parse_by ":hoge" do
      it { is_expected.to unparsed ":hoge" }
    end
    parse_by "/.*hoge$/" do
      it { is_expected.to unparsed "/.*hoge$/" }
    end
    parse_by "/foo/i" do
      it { is_expected.to unparsed "/foo/i" }
    end
    parse_by "/foo bar /x" do
      it { is_expected.to unparsed "/foo bar /x" }
    end
  end

  describe "NODE_STR" do
    parse_by '"hoge"' do
      it { is_expected.to unparsed '"hoge"' }
      it { is_expected.to type_of :STR }
    end
    parse_by '"hoge \#{  \n foo"' do
      it { is_expected.to unparsed '"hoge \#{  \n foo"' }
    end
    parse_by %('hoge "foo"') do
      it { is_expected.to unparsed '"hoge \"foo\""' }
    end
    parse_by %("hoge\nfoo") do
      it { is_expected.to unparsed %{"hoge\\nfoo"} }
    end
    parse_by %("hoge\nfoo 'bar'") do
      it { is_expected.to unparsed %{"hoge\\nfoo 'bar'"} }
    end
    parse_by %('ho\nge') do
      it { is_expected.to unparsed %{"ho\\nge"} }
    end
    parse_by %q('ho#{hoge}ge') do
      it { is_expected.to unparsed %{"ho\\\#{hoge}ge"} }
    end
    parse_by '"\"#{hoge}\""' do
      it { is_expected.to unparsed '"\"#{hoge}\""' }
    end
    parse_by '"\""' do
      it { is_expected.to unparsed '"\""' }
    end
  end

  describe "NODE_XSTR" do
    parse_by "`str`" do
      it { is_expected.to unparsed "`str`" }
    end
  end

  describe "NODE_ONCE" do
    parse_by '/foo#{ bar }baz/o' do
      it { is_expected.to unparsed '/foo#{bar}baz/o' }
      it { is_expected.to type_of :ONCE }
    end
  end

  describe "NODE_DSTR" do
    parse_by '"foo#{ bar }baz"' do
      it { is_expected.to unparsed '"foo#{bar}baz"' }
      it { is_expected.to type_of :DSTR }
    end
    parse_by '"#{ bar }baz"' do
      it { is_expected.to unparsed '"#{bar}baz"' }
      it { is_expected.to type_of :DSTR }
    end
    parse_by '"#{ bar }"' do
      it { is_expected.to unparsed '"#{bar}"' }
      it { is_expected.to type_of :DSTR }
    end
    parse_by '"#{ bar }#{ foo }"' do
      it { is_expected.to unparsed '"#{bar}#{foo}"' }
      it { is_expected.to type_of :DSTR }
    end
    parse_by '"foo#{ bar }#{ foo }"' do
      it { is_expected.to unparsed '"foo#{bar}#{foo}"' }
      it { is_expected.to type_of :DSTR }
    end
    parse_by '"#{ bar }foo#{ foo }"' do
      it { is_expected.to unparsed '"#{bar}foo#{foo}"' }
      it { is_expected.to type_of :DSTR }
    end
    parse_by '"#{ bar }foo#{ foo }bar"' do
      it { is_expected.to unparsed '"#{bar}foo#{foo}bar"' }
      it { is_expected.to type_of :DSTR }
    end
    parse_by '"foo#{ bar + "#{ bar + "hoge" } #{ bar }" }baz"' do
      it { is_expected.to unparsed '"foo#{(bar + "#{(bar + "hoge")} #{bar}")}baz"' }
      it { is_expected.to type_of :DSTR }
    end
    parse_by '"foo#{ "hoge" }baz"', ruby_version: "2.6.0"..."3.0.0" do
      it { is_expected.to unparsed '"foohogebaz"' }
      it { is_expected.to type_of :STR }
    end
    parse_by '"foo#{ "hoge" }baz"', ruby_version: "3.0.0"... do
      it { is_expected.to unparsed '"#{"foohogebaz"}"' }
      it { is_expected.to type_of :DSTR }
    end
    parse_by %q("hoge#{42}foo\nhoge") do
      it { is_expected.to unparsed %q("hoge#{42}foo\nhoge") }
    end
    parse_by %q("hoge \#{ #{42} \n foo") do
      it { is_expected.to unparsed %q("hoge \#{ #{42} \n foo") }
    end
    parse_by %q("'hoge' #{42} 'foo'") do
      it { is_expected.to unparsed "\"'hoge' \#{42} 'foo'\"" }
    end
    parse_by %q("#{ bar }#{ foo + "a" }'a'") do
      it { is_expected.to unparsed %q("#{bar}#{(foo + "a")}'a'") }
    end
  end

  describe "NODE_DXSTR" do
    parse_by '`foo#{ bar }baz`' do
      it { is_expected.to unparsed '`foo#{bar}baz`' }
      it { is_expected.to type_of :DXSTR }
    end
  end

  describe "NODE_DREGX" do
    parse_by '/foo#{ bar }baz/' do
      it { is_expected.to unparsed '/foo#{bar}baz/' }
      it { is_expected.to type_of :DREGX }
    end
    parse_by '/\A#{foo}\A/' do
      it { is_expected.to unparsed %q(/\A#{foo}\A/) }
    end
    parse_by '/\A\#{\}#{foo}\A/' do
      it { is_expected.to unparsed %q(/\A\#{\}#{foo}\A/) }
    end
  end

  describe "NODE_DSYM" do
    parse_by ':"foo#{ bar }baz"' do
      it { is_expected.to unparsed ':"foo#{bar}baz"' }
      it { is_expected.to type_of :DSYM }
    end
  end

  describe "NODE_EVSTR" do
    # Test with NODE_DSTR
    parse_by '"foo#{ bar }baz"' do
      it { is_expected.to satisfy { |node| node.children[1].type == :EVSTR } }
    end
  end

  describe "NODE_ARGSCAT" do
    parse_by 'foo(*ary, post_arg1, post_arg2)' do
      it { is_expected.to unparsed 'foo(*ary, post_arg1, post_arg2)' }
      it { is_expected.to satisfy { |node| node.children[1].type == :ARGSCAT } }
    end
    parse_by 'foo(*ary, *ary2)' do
      it { is_expected.to unparsed 'foo(*ary, *ary2)' }
      it { is_expected.to satisfy { |node| node.children[1].type == :ARGSCAT } }
    end
    parse_by 'foo(*ary, ary2)' do
      it { is_expected.to unparsed 'foo(*ary, ary2)' }
    end
    parse_by 'foo(*ary, ary2, arg3)' do
      it { is_expected.to unparsed 'foo(*ary, ary2, arg3)' }
    end
    parse_by 'foo(ary, *ary2, arg3)' do
      it { is_expected.to unparsed 'foo(ary, *ary2, arg3)' }
    end
    parse_by 'foo(*ary, *ary2, arg3)' do
      it { is_expected.to unparsed 'foo(*ary, *ary2, arg3)' }
    end
    parse_by 'foo(ary, ary2, *arg3)' do
      it { is_expected.to unparsed 'foo(ary, ary2, *arg3)' }
    end
    parse_by 'foo(*ary, ary2, *arg3)' do
      it { is_expected.to unparsed 'foo(*ary, ary2, *arg3)' }
    end
    parse_by 'foo(ary, *ary2, *arg3)' do
      it { is_expected.to unparsed 'foo(ary, *ary2, *arg3)' }
    end
    parse_by 'foo(*ary, *ary2, *arg3)' do
      it { is_expected.to unparsed 'foo(*ary, *ary2, *arg3)' }
    end
    parse_by 'foo(*ary, *ary2, *arg3, arg4)' do
      it { is_expected.to unparsed 'foo(*ary, *ary2, *arg3, arg4)' }
    end
    parse_by 'foo(*ary, *ary2, *arg3, *arg4)' do
      it { is_expected.to unparsed 'foo(*ary, *ary2, *arg3, *arg4)' }
    end
    parse_by 'foo(*ary, ary2, arg3, *arg4)' do
      it { is_expected.to unparsed 'foo(*ary, ary2, arg3, *arg4)' }
    end
    xparse_by 'foo([a, *b])' do
      it { is_expected.to unparsed 'foo([a], *b)' }
    end
    xparse_by 'foo([a, *b, c])' do
      it { is_expected.to unparsed 'foo([a], *b, c)' }
    end
    xparse_by '[a, *b]'
    xparse_by '[a, *b, c]'
  end

  describe "NODE_ARGSPUSH" do
    parse_by 'foo(*ary, ary2)' do
      it { is_expected.to unparsed 'foo(*ary, ary2)' }
      it { is_expected.to satisfy { |node| node.children[1].type == :ARGSPUSH } }
    end
  end

  describe "NODE_SPLAT" do
    parse_by 'foo(*ary)' do
      it { is_expected.to unparsed 'foo(*ary)' }
      it { is_expected.to satisfy { |node| node.children[1].type == :SPLAT } }
    end
    parse_by 'foo(*[1, 2, 3])' do
      it { is_expected.to unparsed 'foo(*[1, 2, 3])' }
      it { is_expected.to satisfy { |node| node.children[1].type == :SPLAT } }
    end
  end

  describe "NODE_BLOCK_PASS" do
    parse_by 'foo(x, &blk)' do
      it { is_expected.to unparsed 'foo(x, &blk)' }
      it { is_expected.to satisfy { |node| node.children[1].type == :BLOCK_PASS } }
    end
    parse_by 'foo(&blk)' do
      it { is_expected.to unparsed 'foo(&blk)' }
      it { is_expected.to satisfy { |node| node.children[1].type == :BLOCK_PASS } }
    end
    parse_by 'foo(x, y, &blk)' do
      it { is_expected.to unparsed 'foo(x, y, &blk)' }
    end
    parse_by 'foo(x, y, &a + b)' do
      it { is_expected.to unparsed 'foo(x, y, &(a + b))' }
    end
  end

  describe "NODE_DEFN" do
    parse_by "def foo; bar; end" do
      it { is_expected.to unparsed(<<~EOS.chomp) }
        def foo()
          bar
        end
      EOS
      it { is_expected.to type_of :DEFN }
    end
    parse_by "def foo(); bar; end" do
      it { is_expected.to unparsed(<<~EOS.chomp) }
        def foo()
          begin; bar; end
        end
      EOS
    end
    parse_by "def foo(a, b); bar; end" do
      it { is_expected.to unparsed(<<~EOS.chomp) }
        def foo(a, b)
          begin; bar; end
        end
      EOS
    end
    parse_by "def foo(a, b = 1); bar; end" do
      it { is_expected.to unparsed(<<~EOS.chomp) }
        def foo(a, b = 1)
          begin; bar; end
        end
      EOS
    end
    parse_by "def foo(a, b = 1, c); bar; end" do
      it { is_expected.to unparsed(<<~EOS.chomp) }
        def foo(a, b = 1, c)
          begin; bar; end
        end
      EOS
    end
    parse_by "def foo(a, *b, c); bar; end" do
      it { is_expected.to unparsed(<<~EOS.chomp) }
        def foo(a, *b, c)
          begin; bar; end
        end
      EOS
    end
    parse_by "def foo(a, b:, **kwd); bar; end" do
      it { is_expected.to unparsed(<<~EOS.chomp) }
        def foo(a, b:, **kwd)
          begin; bar; end
        end
      EOS
    end
  end

  describe "NODE_DEFS" do
    parse_by "def obj.foo; bar; end" do
      it { is_expected.to unparsed(<<~EOS.chomp) }
        def obj.foo()
          bar
        end
      EOS
      it { is_expected.to type_of :DEFS }
    end
    parse_by "def obj.foo(); bar; end" do
      it { is_expected.to unparsed(<<~EOS.chomp) }
        def obj.foo()
          begin; bar; end
        end
      EOS
    end
    parse_by "def obj.foo(a, b); bar; end" do
      it { is_expected.to unparsed(<<~EOS.chomp) }
        def obj.foo(a, b)
          begin; bar; end
        end
      EOS
    end
    parse_by "def obj.foo(a, *b, c); bar; end" do
      it { is_expected.to unparsed(<<~EOS.chomp) }
        def obj.foo(a, *b, c)
          begin; bar; end
        end
      EOS
    end
    parse_by "def obj.foo(a, b:, **kwd); bar; end" do
      it { is_expected.to unparsed(<<~EOS.chomp) }
        def obj.foo(a, b:, **kwd)
          begin; bar; end
        end
      EOS
    end
  end

  describe "NODE_ALIAS" do
    parse_by "alias bar foo" do
      it { is_expected.to unparsed "alias :bar :foo" }
      it { is_expected.to type_of :ALIAS }
    end
    parse_by "alias :bar :foo" do
      it { is_expected.to unparsed "alias :bar :foo" }
    end
  end

  describe "NODE_VALIAS" do
    parse_by "alias $y $x" do
      it { is_expected.to unparsed "alias $y $x" }
      it { is_expected.to type_of :VALIAS }
    end
  end

  describe "NODE_UNDEF" do
    parse_by "undef foo" do
      it { is_expected.to unparsed "undef :foo" }
      it { is_expected.to type_of :UNDEF }
    end
    parse_by "undef :foo" do
      it { is_expected.to unparsed "undef :foo" }
    end
  end

  describe "NODE_CLASS" do
    parse_by "class C; foo; end" do
      it { is_expected.to unparsed(<<~EOS.chomp) }
        class C
          foo
        end
      EOS
      it { is_expected.to type_of :CLASS }
    end
    parse_by "class C < C2; foo; end" do
      it { is_expected.to unparsed(<<~EOS.chomp) }
        class C < C2
          foo
        end
      EOS
    end
    parse_by "class M::C < C2; foo; end" do
      it { is_expected.to unparsed(<<~EOS.chomp) }
        class M::C < C2
          foo
        end
      EOS
    end
    parse_by "class M::C < C2; foo; bar; end" do
      it { is_expected.to unparsed(<<~EOS.chomp) }
        class M::C < C2
          foo; bar
        end
      EOS
    end
    parse_by "class M::C < C2; a = 1; b = 2; end" do
      it { is_expected.to unparsed(<<~EOS.chomp) }
        class M::C < C2
          (a = 1); (b = 2)
        end
      EOS
    end
    parse_by "class M::C < C2; class C3 < C4; a = 1; b = 2; end; end" do
      it { is_expected.to unparsed(<<~EOS.chomp) }
        class M::C < C2
          class C3 < C4
          (a = 1); (b = 2)
        end
        end
      EOS
    end
  end

  describe "NODE_MODULE" do
    parse_by "module M; foo; end" do
      it { is_expected.to unparsed(<<~EOS.chomp) }
        module M
          foo
        end
      EOS
      it { is_expected.to type_of :MODULE }
    end
    parse_by "module C::M2; foo; end" do
      it { is_expected.to unparsed(<<~EOS.chomp) }
        module C::M2
          foo
        end
      EOS
    end
  end

  describe "NODE_SCLASS" do
    parse_by "class << obj; foo; end" do
      it { is_expected.to unparsed(<<~EOS.chomp) }
        class << obj
          foo
        end
      EOS
      it { is_expected.to type_of :SCLASS }
    end
    parse_by "class << obj.hoge; foo; end" do
      it { is_expected.to unparsed(<<~EOS.chomp) }
        class << obj.hoge()
          foo
        end
      EOS
    end
    parse_by "class << (obj + obj2); foo; end" do
      it { is_expected.to unparsed(<<~EOS.chomp) }
        class << (obj + obj2)
          foo
        end
      EOS
    end
  end

  describe "NODE_COLON2" do
    parse_by "X::Y" do
      it { is_expected.to unparsed "X::Y" }
      it { is_expected.to type_of :COLON2 }
    end
    parse_by "X::Y::Z" do
      it { is_expected.to unparsed "X::Y::Z" }
    end
    parse_by "func::X" do
      it { is_expected.to unparsed "func::X" }
    end
    parse_by "func::X" do
      it { is_expected.to unparsed "func::X" }
    end
    parse_by "class C; foo; end" do
      it { is_expected.to unparsed(<<~EOS.chomp) }
        class C
          foo
        end
      EOS
      it { is_expected.to children_type_of :COLON2 }
    end
  end

  describe "NODE_COLON3" do
    parse_by "::X" do
      it { is_expected.to unparsed "::X" }
      it { is_expected.to type_of :COLON3 }
    end
    parse_by "::X::Y" do
      it { is_expected.to unparsed "::X::Y" }
    end
    parse_by "::X::func()" do
      it { is_expected.to unparsed "::X.func()" }
    end
    parse_by "::X::func" do
      it { is_expected.to unparsed "::X.func()" }
    end
    parse_by "::X::func 42" do
      it { is_expected.to unparsed "::X.func(42)" }
    end
  end

  describe "NODE_DOT2" do
    parse_by "1..5" do
      it { is_expected.to unparsed "(1..5)" }
      it { is_expected.to type_of :DOT2 }
    end
    parse_by "(1..5)" do
      it { is_expected.to unparsed "(1..5)" }
    end
    parse_by "1.." do
      it { is_expected.to unparsed "(1..nil)" }
    end
    parse_by "..5", ruby_version: "2.7.0"... do
      it { is_expected.to unparsed "(nil..5)" }
    end
  end

  describe "NODE_DOT3" do
    parse_by "1...5" do
      it { is_expected.to unparsed "(1...5)" }
      it { is_expected.to type_of :DOT3 }
    end
    parse_by "1...;" do
      it { is_expected.to unparsed "(1...nil)" }
    end
    if RUBY_VERSION >= "2.7.0"
      parse_by "...5" do
        it { is_expected.to unparsed "(nil...5)" }
      end
    end
  end

  describe "NODE_FLIP2" do
    parse_by "if (x==1)..(x==5); foo; end" do
      it { is_expected.to unparsed(<<~EOS.chomp) }
        if ((x == 1))..((x == 5))
          foo
        end
      EOS
      it { is_expected.to children_type_of :FLIP2 }
    end
  end

  describe "NODE_FLIP3" do
    parse_by "if (x==1)...(x==5); foo; end" do
      it { is_expected.to unparsed(<<~EOS.chomp) }
        if ((x == 1))...((x == 5))
          foo
        end
      EOS
      it { is_expected.to children_type_of :FLIP3 }
    end
  end

  describe "NODE_SELF" do
    parse_by "self" do
      it { is_expected.to unparsed "self" }
      it { is_expected.to type_of :SELF }
    end
  end

  describe "NODE_NIL" do
    parse_by "nil" do
      it { is_expected.to unparsed "nil" }
      it { is_expected.to type_of :NIL }
    end
  end

  describe "NODE_TRUE" do
    parse_by "true" do
      it { is_expected.to unparsed "true" }
      it { is_expected.to type_of :TRUE }
    end
  end

  describe "NODE_FALSE" do
    parse_by "false" do
      it { is_expected.to unparsed "false" }
      it { is_expected.to type_of :FALSE }
    end
  end

  describe "NODE_ERRINFO" do
    # NODE_RESCUE
  end

  describe "NODE_DEFINED" do
    parse_by "defined?(foo)" do
      it { is_expected.to unparsed "defined?(foo)" }
      it { is_expected.to type_of :DEFINED }
    end
    parse_by "defined? foo" do
      it { is_expected.to unparsed "defined?(foo)" }
    end
  end

  describe "NODE_POSTEXE" do
    parse_by "END { foo }" do
      it { is_expected.to unparsed "END { foo }" }
      it { is_expected.to type_of :POSTEXE }
    end
  end

  describe "NODE_ATTRASGN" do
    parse_by "struct.field = foo" do
      it { is_expected.to unparsed "struct.field=foo" }
      it { is_expected.to type_of :ATTRASGN }
    end
    parse_by "struct.field = 1, 2, 3" do
      it { is_expected.to unparsed "struct.field=[1, 2, 3]" }
    end
    parse_by "struct[field] = foo" do
      it { is_expected.to unparsed "struct[field] = foo" }
    end
    parse_by "struct[a, b] = c" do
      it { is_expected.to unparsed "struct[a, b] = c" }
    end
    parse_by "struct[a] = b, c" do
      it { is_expected.to unparsed "struct[a] = b, c" }
    end
  end

  describe "NODE_LAMBDA" do
    parse_by "-> { foo }" do
      it { is_expected.to unparsed "-> () { foo }" }
      it { is_expected.to type_of :LAMBDA }
    end
    parse_by "-> () { foo }" do
      it { is_expected.to unparsed "-> () { foo }" }
    end
    parse_by "-> (a, b) { foo }" do
      it { is_expected.to unparsed "-> (a, b) { foo }" }
    end
    parse_by "-> (a, *b, c) { foo }" do
      it { is_expected.to unparsed "-> (a, *b, c) { foo }" }
    end
    parse_by "-> (a:, b: 1) { foo }" do
      it { is_expected.to unparsed "-> (a:, b: 1) { foo }" }
    end
  end

  describe "NODE_OPT_ARG" do
    parse_by "proc { |a = 1| foo }" do
      it { is_expected.to unparsed "proc() { |a = 1| foo }" }
    end
  end

  describe "NODE_KW_ARG" do
    context "block" do
      parse_by "proc { |a:, b:| foo }" do
        it { is_expected.to unparsed "proc() { |a:, b:| foo }" }
      end
      parse_by "proc { |a:, b: 1| foo }" do
        it { is_expected.to unparsed "proc() { |a:, b: 1| foo }" }
      end
      parse_by "proc { |a:, b: 1, c:| foo }" do
        it { is_expected.to unparsed "proc() { |a:, b: 1, c:| foo }" }
      end
    end
  end

  describe "NODE_POSTARG" do
    parse_by "a, *rest, z = foo" do
      it { is_expected.to unparsed "(a, *rest, z) = foo" }
    end
  end

  describe "NODE_ARGS" do
    context "pre_init" do
      parse_by "proc { foo }" do
        it { is_expected.to unparsed "proc() { foo }" }
      end
      parse_by "proc { |a| foo }" do
        it { is_expected.to unparsed "proc() { |a| foo }" }
      end
      parse_by "proc { |a, b| foo }" do
        it { is_expected.to unparsed "proc() { |a, b| foo }" }
      end
      parse_by "proc { |(a)| foo }" do
        it { is_expected.to unparsed "proc() { |(a)| foo }" }
      end
      parse_by "proc { |(a, b)| foo }" do
        it { is_expected.to unparsed "proc() { |(a, b)| foo }" }
      end
      parse_by "proc { |((a), b)| foo }" do
        it { is_expected.to unparsed "proc() { |((a), b)| foo }" }
      end
      parse_by "proc { |(a, b), (c, d)| foo }" do
        it { is_expected.to unparsed "proc() { |(a, b), (c, d)| foo }" }
      end
    end

    context "rest" do
      parse_by "proc { |*a| foo }" do
        it { is_expected.to unparsed "proc() { |*a| foo }" }
      end
      parse_by "proc { |a, *b| foo }" do
        it { is_expected.to unparsed "proc() { |a, *b| foo }" }
      end
      parse_by "proc { |a, b, *c| foo }" do
        it { is_expected.to unparsed "proc() { |a, b, *c| foo }" }
      end
      parse_by "proc { |a, *b, c| foo }" do
        it { is_expected.to unparsed "proc() { |a, *b, c| foo }" }
      end
    end

    context "first_post" do
      parse_by "proc { |a, *b, c| foo }" do
        it { is_expected.to unparsed "proc() { |a, *b, c| foo }" }
      end
      parse_by "proc { |a, *b, c, d| foo }" do
        it { is_expected.to unparsed "proc() { |a, *b, c, d| foo }" }
      end
      parse_by "proc { |*a, b, c| foo }" do
        it { is_expected.to unparsed "proc() { |*a, b, c| foo }" }
      end
      parse_by "proc { |a = 1, b = 2, c| foo }" do
        it { is_expected.to unparsed "proc() { |a = 1, b = 2, c| foo }" }
      end
    end

    context "post" do
      parse_by "proc { |a = 1, (b, c)| foo }" do
        it { is_expected.to unparsed "proc() { |a = 1, (b, c)| foo }" }
      end
      parse_by "proc { |a = 1, b, (c, d), e| foo }" do
        it { is_expected.to unparsed "proc() { |a = 1, b, (c, d), e| foo }" }
      end
      parse_by "proc { |a, b = 1, (c, d)| foo }" do
        it { is_expected.to unparsed "proc() { |a, b = 1, (c, d)| foo }" }
      end
      parse_by "proc { |(a, b), *, (c, d)| foo }" do
        it { is_expected.to unparsed "proc() { |(a, b), *, (c, d)| foo }" }
      end
    end

    context "opt" do
      parse_by "proc { |a = 1| foo }" do
        it { is_expected.to unparsed "proc() { |a = 1| foo }" }
      end
      parse_by "proc { |a, b = 1| foo }" do
        it { is_expected.to unparsed "proc() { |a, b = 1| foo }" }
      end
      parse_by "proc { |a = 1, b = 2| foo }" do
        it { is_expected.to unparsed "proc() { |a = 1, b = 2| foo }" }
      end
      parse_by "proc { |a, b, c = 1| foo }" do
        it { is_expected.to unparsed "proc() { |a, b, c = 1| foo }" }
      end
      parse_by "proc { |a, b = 1, c = 1| foo }" do
        it { is_expected.to unparsed "proc() { |a, b = 1, c = 1| foo }" }
      end
      parse_by "proc { |a, b = 42, c| }" do
        it { is_expected.to unparsed "proc() { |a, b = 42, c|  }" }
      end
      parse_by "proc { |a, b = 1, c = 2, d = 3, e| }" do
        it { is_expected.to unparsed "proc() { |a, b = 1, c = 2, d = 3, e|  }" }
      end
    end

    context "kw" do
      parse_by "proc { |a:, b:| }" do
        it { is_expected.to unparsed "proc() { |a:, b:|  }" }
      end
      parse_by "proc { |a:, b: 1| }" do
        it { is_expected.to unparsed "proc() { |a:, b: 1|  }" }
      end
      parse_by "proc { |a: 1, b:| }" do
        it { is_expected.to unparsed "proc() { |a: 1, b:|  }" }
      end
      parse_by "proc { |a: 1, b: 2| }" do
        it { is_expected.to unparsed "proc() { |a: 1, b: 2|  }" }
      end
      parse_by "proc { |**| }" do
        it { is_expected.to unparsed "proc() { |**|  }" }
      end
    end

    context "rest" do
      parse_by 'proc { |a,| }', ruby_version: "2.7.2"... do
        it { is_expected.to unparsed 'proc() { |a,  |  }' }
      end
    end

    context "kwrest" do
      parse_by "proc { |**kwd| }" do
        it { is_expected.to unparsed "proc() { |**kwd|  }" }
      end
      parse_by "proc { |**| }" do
        it { is_expected.to unparsed "proc() { |**|  }" }
      end
      parse_by "proc { |a:, **| }" do
        it { is_expected.to unparsed "proc() { |a:, **|  }" }
      end
      parse_by "proc { |a:, **kwd| }" do
        it { is_expected.to unparsed "proc() { |a:, **kwd|  }" }
      end
      parse_by "proc { |a:, b:, **kwd| }" do
        it { is_expected.to unparsed "proc() { |a:, b:, **kwd|  }" }
      end
      parse_by "proc { |a:, b: 1, c: 2, **kwd| }" do
        it { is_expected.to unparsed "proc() { |a:, b: 1, c: 2, **kwd|  }" }
      end
      parse_by "proc { |a:, b: 1, c: 2, **| }" do
        it { is_expected.to unparsed "proc() { |a:, b: 1, c: 2, **|  }" }
      end
    end

    context "block" do
      parse_by "proc { |&block| }" do
        it { is_expected.to unparsed "proc() { |&block|  }" }
      end
      parse_by "proc { |&hoge| }" do
        it { is_expected.to unparsed "proc() { |&hoge|  }" }
      end
    end

    context "`*`" do
      parse_by "proc { |*| }" do
        it { is_expected.to unparsed "proc() { |*|  }" }
      end
      parse_by "proc { |*, a, b| }" do
        it { is_expected.to unparsed "proc() { |*, a, b|  }" }
      end
      parse_by "proc { |a, b, *| }" do
        it { is_expected.to unparsed "proc() { |a, b, *|  }" }
      end
      parse_by "proc { |a, *, b| }" do
        it { is_expected.to unparsed "proc() { |a, *, b|  }" }
      end
    end

    context "other" do
      parse_by "proc { |(a, *b)| foo }" do
        it { is_expected.to unparsed "proc() { |(a, *b)| foo }" }
      end
      parse_by "proc { |a, (b, c), d, (e, *f), g, (h, i, *j)| foo }" do
        it { is_expected.to unparsed "proc() { |a, (b, c), d, (e, *f), g, (h, i, *j)| foo }" }
      end
      parse_by "proc { |(a, b), *c| foo }" do
        it { is_expected.to unparsed "proc() { |(a, b), *c| foo }" }
      end
      parse_by "proc { |a, b = 1, *c| foo }" do
        it { is_expected.to unparsed "proc() { |a, b = 1, *c| foo }" }
      end
      parse_by "proc { |a1, a2, a3, b1 = 1, b2 = 2, *c1| foo }" do
        it { is_expected.to unparsed "proc() { |a1, a2, a3, b1 = 1, b2 = 2, *c1| foo }" }
      end
      parse_by "proc { |a, (b, c), d = 1| foo }" do
        it { is_expected.to unparsed "proc() { |a, (b, c), d = 1| foo }" }
      end
      parse_by "proc { |a, (x, y), b = 2, (c, d)| foo }" do
        it { is_expected.to unparsed "proc() { |a, (x, y), b = 2, (c, d)| foo }" }
      end
      parse_by "proc { |a1, a2, a3, b1 = 1, b2 = 2, *c1| foo }" do
        it { is_expected.to unparsed "proc() { |a1, a2, a3, b1 = 1, b2 = 2, *c1| foo }" }
      end
      parse_by "proc { |a1, (a2, a3), b1 = 1, b2 = 2, *c1| foo }" do
        it { is_expected.to unparsed "proc() { |a1, (a2, a3), b1 = 1, b2 = 2, *c1| foo }" }
      end
      parse_by "proc { |a, b = 1, *c| foo }" do
        it { is_expected.to unparsed "proc() { |a, b = 1, *c| foo }" }
      end
      parse_by "proc { |a, b = 1, (c, d)| foo }" do
        it { is_expected.to unparsed "proc() { |a, b = 1, (c, d)| foo }" }
      end
      parse_by "proc { |a, b = 1, (c, *d)| foo }" do
        it { is_expected.to unparsed "proc() { |a, b = 1, (c, *d)| foo }" }
      end
      parse_by "proc { |a, *b, (c, *d), e, f| foo }" do
        it { is_expected.to unparsed "proc() { |a, *b, (c, *d), e, f| foo }" }
      end
      parse_by "proc { |a, (x, y, z), b = 2, *c, (d, e, f), g, h| foo }" do
        it { is_expected.to unparsed "proc() { |a, (x, y, z), b = 2, *c, (d, e, f), g, h| foo }" }
      end
      parse_by "proc { |x, y, (a, b), (c, d), e, (f, g), h = 1, *i| foo }" do
        it { is_expected.to unparsed "proc() { |x, y, (a, b), (c, d), e, (f, g), h = 1, *i| foo }" }
      end
      parse_by "proc { |x, y, (a, b), (c, d), e, (f, g), h = 1, *i, j:, k: 1| foo }" do
        it { is_expected.to unparsed "proc() { |x, y, (a, b), (c, d), e, (f, g), h = 1, *i, j:, k: 1| foo }" }
      end
      parse_by "proc { |x, y, (a, b), (c, d), e, (f, g), h = 1, *i, j:, k: 1, **| foo }" do
        it { is_expected.to unparsed "proc() { |x, y, (a, b), (c, d), e, (f, g), h = 1, *i, j:, k: 1, **| foo }" }
      end
      parse_by "proc { |x, y, (a, b), (c, d), e, (f, g), h = 1, *i, j:, k: 1, **kw| foo }" do
        it { is_expected.to unparsed "proc() { |x, y, (a, b), (c, d), e, (f, g), h = 1, *i, j:, k: 1, **kw| foo }" }
      end
      parse_by "proc { |(c, d), e, (f, g), h = 1, *i, j:, k: 1| foo }" do
        it { is_expected.to unparsed "proc() { |(c, d), e, (f, g), h = 1, *i, j:, k: 1| foo }" }
      end
      parse_by "proc { |a = 1, x, y, z, (c, d), e| foo }" do
        it { is_expected.to unparsed "proc() { |a = 1, x, y, z, (c, d), e| foo }" }
      end
      parse_by "proc { |a, b = 1, (c, d)| foo }" do
        it { is_expected.to unparsed "proc() { |a, b = 1, (c, d)| foo }" }
      end
      parse_by "proc { |(a, b), *, (c, d)| foo }" do
        it { is_expected.to unparsed "proc() { |(a, b), *, (c, d)| foo }" }
      end
      parse_by "proc { |z, (a, b), c = 1, d = 2, *, (e, f, g), (h, i), j, k, l:, **kwd| foo }" do
        it { is_expected.to unparsed "proc() { |z, (a, b), c = 1, d = 2, *, (e, f, g), (h, i), j, k, l:, **kwd| foo }" }
      end
    end
  end

  describe "NODE_SCOPE" do
    parse_by "3.times { foo }" do
      it { is_expected.to unparsed "3.times() { foo }" }
    end
    parse_by "3.times(3) { foo }" do
      it { is_expected.to unparsed "3.times(3) { foo }" }
    end
    parse_by "3.times { foo; bar }" do
      it { is_expected.to unparsed "3.times() { begin foo; bar; end }" }
    end
  end

  xdescribe "NODE_ARYPTN" do
    # :TODO:
  end

  xdescribe "NODE_HSHPTN" do
    # :TODO:
  end

  describe "NODE_ARGS_AUX" do
    # Unknown
  end

  describe "NODE_LAST" do
    # Unknown
  end

  context "other" do
    parse_by "x = foo; f(42)" do
      it { is_expected.to unparsed "begin (x = foo); f(42); end" }
    end
    parse_by "if x = foo then hoge end" do
      it { is_expected.to unparsed(<<~EOS.chomp) }
        if (x = foo)
          hoge
        end
      EOS
    end
    parse_by "hoge += foo" do
      it { is_expected.to unparsed "(hoge = hoge.+(foo))" }
    end

    context "`AND` with `OR`" do
      parse_by "foo || bar && hoge" do
        it { is_expected.to unparsed "(foo || (bar && hoge))" }
      end
      parse_by "foo || bar and hoge" do
        it { is_expected.to unparsed "((foo || bar) && hoge)" }
      end
      parse_by "foo or bar && hoge" do
        it { is_expected.to unparsed "(foo || (bar && hoge))" }
      end
      parse_by "foo or bar and hoge" do
        it { is_expected.to unparsed "((foo || bar) && hoge)" }
      end
      parse_by "foo && bar || hoge" do
        it { is_expected.to unparsed "((foo && bar) || hoge)" }
      end
      parse_by "foo and bar || hoge" do
        it { is_expected.to unparsed "(foo && (bar || hoge))" }
      end
      parse_by "foo && bar or hoge" do
        it { is_expected.to unparsed "((foo && bar) || hoge)" }
      end
      parse_by "foo and bar or hoge" do
        it { is_expected.to unparsed "((foo && bar) || hoge)" }
      end
      parse_by "x = foo || bar and hoge" do
        it { is_expected.to unparsed "((x = (foo || bar)) && hoge)" }
      end
      parse_by "x = foo or bar and hoge" do
        it { is_expected.to unparsed "(((x = foo) || bar) && hoge)" }
      end
    end
  end

  describe "with Hash" do
    context "by 2.6.0", ruby_version: "2.6.0"..."2.7.0" do
      let(:node) {
        {:type=>:OPCALL,
         :children=>
          [{:type=>:LIT, :children=>[1]},
           :+,
           {:type=>:ARRAY, :children=>[{:type=>:LIT, :children=>[2]}, nil]}]}
      }
      it { is_expected.to unparsed "(1 + 2)" }
    end
    context "by 2.7.0", ruby_version: "2.7.0"... do
      let(:node) {
        {:type=>:OPCALL,
         :children=>
          [{:type=>:LIT, :children=>[1]},
           :+,
           {:type=>:LIST, :children=>[{:type=>:LIT, :children=>[2]}, nil]}]}
      }
      it { is_expected.to unparsed "(1 + 2)" }
    end
  end

  describe "with Array" do
    context "by 2.6.0", ruby_version: "2.6.0"..."2.7.0" do
      let(:node) {
        [:OPCALL, [[:LIT, [1]], :+, [:ARRAY, [[:LIT, [2]], nil]]]]
      }
      it { is_expected.to unparsed "(1 + 2)" }
    end
    context "by 2.7.0", ruby_version: "2.7.0"... do
      let(:node) {
        [:OPCALL, [[:LIT, [1]], :+, [:LIST, [[:LIT, [2]], nil]]]]
      }
      it { is_expected.to unparsed "(1 + 2)" }
    end
  end
end
