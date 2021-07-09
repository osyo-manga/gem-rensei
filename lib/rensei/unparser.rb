module Rensei
  module Unparser
    class NoImplemented < StandardError; end

    using Module.new {
      refine Hash do
        def type
          self[:type]
        end

        def children
          self[:children]
        end

        def except(*keys)
          slice(*self.keys - keys)
        end
      end

      refine Array do
        def type
          self[0]
        end

        def children
          self[1]
        end
      end

      refine String do
        def bracket(prefix = "(", suffix = ")")
          "#{prefix}#{self}#{suffix}"
        end

        def escape
          dump[1..-2]
        end
      end
    }

    module Base
      def unparse(node, opt = {})
        case node
        when RubyVM::AbstractSyntaxTree::Node, Hash, Array
          method_name = "NODE_#{node.type}"
          respond_to?(method_name, true) ? send(method_name, node, opt.dup) : node
        else
          node
        end
      end

      private

      def _unparse(opt = {})
        proc { |node| unparse(node, opt.dup) }
      end

      # statement sequence
      # format: [nd_head]; ...; [nd_next]
      # example: foo; bar
      def NODE_BLOCK(node, opt = {})
        node.children.then { |head, *nexts|
          if head&.type == :BEGIN && opt[:without_BEGIN]
            nexts.map(&_unparse(opt.except(:without_BEGIN))).join("; ")
          elsif opt[:without_BEGIN]
            [head, *nexts].map(&_unparse(opt.except(:without_BEGIN))).join("; ")
          # Support by BEGIN { foo }
          elsif nexts&.first&.type == :BEGIN
            "BEGIN { #{unparse(head.children.first, opt)} }"
          elsif head.type == :BEGIN
            "begin; #{nexts.map(&_unparse(opt)).join("; ")}; end"
          else
            if nexts.empty?
              "#{unparse(head, opt)};"
            else
              "begin #{[head, *nexts].map(&_unparse(opt)).join("; ")}; end"
            end
          end
        }
      end

      # if statement
      # format: if [nd_cond] then [nd_body] else [nd_else] end
      # example: if x == 1 then foo else bar end
      def NODE_IF(node, opt = {})
        node.children.then { |cond, body, else_|
          <<~EOS.chomp
            if #{unparse(cond, opt)}
              #{unparse(body, opt)}#{else_ ? "\nelse\n  #{unparse(else_, opt)}" : ""}
            end
          EOS
        }
      end

      # unless statement
      # format: unless [nd_cond] then [nd_body] else [nd_else] end
      # example: unless x == 1 then foo else bar end
      def NODE_UNLESS(node, opt = {})
        node.children.then { |cond, body, else_|
          <<~EOS.chomp
            unless #{unparse(cond, opt)}
              #{unparse(body, opt)}#{else_ ? "\nelse\n  #{unparse(else_, opt)}" : ""}
            end
          EOS
        }
      end

      # case statement
      # format: case [nd_head]; [nd_body]; end
      # example: case x; when 1; foo; when 2; bar; else baz; end
      def NODE_CASE(node, opt)
        node.children.then { |head, body, else_|
          <<~EOS.chomp
          case #{unparse(head, opt)}
          #{unparse(body, opt)}#{else_ ? "\nelse\n#{unparse(else_, opt)}" : ""}
          end
          EOS
        }
      end

      # case statement with no head
      # format: case; [nd_body]; end
      # example: case; when 1; foo; when 2; bar; else baz; end
      def NODE_CASE2(node, opt = {})
        node.children.then { |_, body, else_|
          <<~EOS.chomp
          case
          #{unparse(body, opt)}#{else_ ? "\nelse\n#{unparse(else_, opt)}" : ""}
          end
          EOS
        }
      end

      # when clause
      # format: when [nd_head]; [nd_body]; (when or else) [nd_next]
      # example: case x; when 1; foo; when 2; bar; else baz; end
      def NODE_WHEN(node, opt = {})
        node.children.then { |head, body, next_|
          <<~EOS.chomp
          when #{unparse(head, opt.merge(expand_ARRAY: true))}
            #{unparse(body, opt)}
          #{next_&.type == :WHEN || next_.nil? ? unparse(next_, opt) : "else\n  #{unparse(next_, opt)}"}
          EOS
        }
      end

      # while statement
      # format: while [nd_cond]; [nd_body]; end
      # example: while x == 1; foo; end
      def NODE_WHILE(node, opt = {})
        node.children.then { |cond, body, state|
          # MEMO: state is not supported Ruby 2.6
          state = true if state.nil?
          if state
            <<~EOS.chomp
            while #{unparse(cond, opt)}
              #{unparse(body, opt)}
            end
            EOS
          # state: begin-end-while
          else
            <<~EOS.chomp
            begin
              #{unparse(body, opt)}
            end while #{unparse(cond, opt)}
            EOS
          end
        }
      end

      # until statement
      # format: until [nd_cond]; [nd_body]; end
      # example: until x == 1; foo; end
      def NODE_UNTIL(node, opt = {})
        node.children.then { |cond, body, state|
          # MEMO: state is not supported Ruby 2.6
          state = true if state.nil?
          if state
            <<~EOS.chomp
            until #{unparse(cond, opt)}
              #{unparse(body, opt)}
            end
            EOS
          # state: begin-end-until
          else
            <<~EOS.chomp
            begin
              #{unparse(body, opt)}
            end until #{unparse(cond, opt)}
            EOS
          end
        }
      end

      # method call with block
      # format: [nd_iter] { [nd_body] }
      # example: 3.times { foo }
      def NODE_ITER(node, opt = {})
        node.children.then { |iter, body|
          "#{unparse(iter, opt)} { #{unparse(body, opt)} }"
        }
      end

      # for statement
      # format: for * in [nd_iter] do [nd_body] end
      # example: for i in 1..3 do foo end
      def NODE_FOR(node, opt = {})
        node.children.then { |iter, body, var|
          scope = unparse_NODE_SCOPE(body, opt)
          <<~EOS.chomp
          for #{unparse(scope[:args], opt) || "*"} in #{unparse(iter, opt)} do
            #{scope[:body]}
          end
          EOS
        }
      end

      # vars of for statement with masgn
      # format: for [nd_var] in ... do ... end
      # example: for x, y in 1..3 do foo end
      def NODE_FOR_MASGN(node, opt = {})
        # Support from NODE_MASGN
      end

      # break statement
      # format: break [nd_stts]
      # example: break 1
      def NODE_BREAK(node, opt = {})
        node.children.then { |stts,|
          "break #{unparse(stts, opt)}"
        }
      end

      # next statement
      # format: next [nd_stts]
      # example: next 1
      def NODE_NEXT(node, opt = {})
        node.children.then { |stts,|
          "next #{unparse(stts, opt)}"
        }
      end

      # return statement
      # format: return [nd_stts]
      # example: return 1
      def NODE_RETURN(node, opt = {})
        node.children.then { |stts,|
          "(return #{unparse(stts, opt)})"
        }
      end

      # redo statement
      # format: redo
      # example: redo
      def NODE_REDO(node, opt = {})
        "redo"
      end

      # retry statement
      # format: retry
      # example: retry
      def NODE_RETRY(node, opt = {})
        "retry"
      end

      # begin statement
      # format: begin; [nd_body]; end
      # example: begin; 1; end
      def NODE_BEGIN(node, opt = {})
        return "" if node.children.first.nil?
        node.children.then { |body|
          <<~EOS.chomp
          begin
            #{body.map(&_unparse(opt)).join("; ")}
          end
          EOS
        }
      end

      # rescue clause
      # format: begin; [nd_body]; (rescue) [nd_resq]; else [nd_else]; end
      # example: begin; foo; rescue; bar; else; baz; end
      def NODE_RESCUE(node, opt = {})
        node.children.then { |body, resq, else_|
          <<~EOS.chomp
          begin
            #{unparse(body, opt)}
          #{unparse(resq, opt)}#{else_ ? "\nelse\n  #{unparse(else_)}" : ""}
          end
          EOS
        }
      end

      # rescue clause (cont'd)
      # format: rescue [nd_args]; [nd_body]; (rescue) [nd_head]
      # example: begin; foo; rescue; bar; else; baz; end
      def NODE_RESBODY(node, opt = {})
        node.children.then { |args, body|
          args_ = args&.then { |it| unparse(it, opt.merge(expand_ARRAY: true)) + ";" }
          if body.type == :BLOCK
            if body.children.first&.children[1]&.type == :ERRINFO
              "rescue #{args_}#{unparse(body, opt.merge(without_BEGIN: true))}"
            else
              "rescue #{args_ || ";"}#{unparse(body, opt)}"
            end
          else
            # MEMO: Support by `begin; foo; rescue; bar; else; baz; end`
            "rescue #{args_ || ";"} #{unparse(body, opt)}"
          end
        }
      end

      # ensure clause
      # format: begin; [nd_head]; ensure; [nd_ensr]; end
      # example: begin; foo; ensure; bar; end
      def NODE_ENSURE(node, opt = {})
        node.children.then { |head, ensr|
          <<~EOS.chomp
          begin
            #{unparse(head, opt)}
          ensure
            #{unparse(ensr, opt)}
          end
          EOS
        }
      end

      # && operator
      # format: [nd_1st] && [nd_2nd]
      # example: foo && bar
      def NODE_AND(node, opt = {})
        node.children.then { |args|
          "(#{args.map { |node| unparse(node, opt) }.join(" && ")})"
        }
      end

      # || operator
      # format: [nd_1st] || [nd_2nd]
      # example: foo || bar
      def NODE_OR(node, opt = {})
        node.children.then { |args|
          # Support pattern match
          # in String | Integer
          if opt[:pattern_match_OR]
            "#{args.map { |node| unparse(node, opt) }.join(" | ")}"
          else
            "(#{args.map { |node| unparse(node, opt) }.join(" || ")})"
          end
        }
      end

      # multiple assignment
      # format: [nd_head], [nd_args] = [nd_value]
      # example: a, b = foo
      def NODE_MASGN(node, opt = {})
        node_masgn = opt[:_NODE_MASGN]
        node.children.then { |right, left, _NODE_SPECIAL_NO_NAME_REST = :dummy|
          # Support: for x, y in 1..3 do foo end
          _right = unparse(right, opt)&.then { |it|
            right.type == :FOR_MASGN || it.empty? ? ""  : " = #{it}"
          }


          # Support: (a,) = value
          if _right&.empty?
            _left = unparse(left, opt.merge(expand_ARRAY: true)) || "*"
          elsif left
            if node_masgn && left.children.count <= 2
              _left = left.children.map(&_unparse(opt.merge(expand_ARRAY: true))).first
            else
              _left = left.children.map(&_unparse(opt.merge(expand_ARRAY: true))).join(", ")
            end
          end

          # Support: for * in 1..3 do foo end
          #          * = foo
          #          a, b, * = foo
          if _NODE_SPECIAL_NO_NAME_REST
            # Support `(a, *) = foo` by 2.6
            if _NODE_SPECIAL_NO_NAME_REST == :dummy
              vname = ""
            elsif _NODE_SPECIAL_NO_NAME_REST != :NODE_SPECIAL_NO_NAME_REST
              vname = unparse(_NODE_SPECIAL_NO_NAME_REST, opt)
            end
            if node_masgn
              _left = left.nil? || _left.empty? ? "*#{vname}" : "#{_left}, *#{vname}"
            else
              _left = left.nil? || _left.empty? ? "*#{vname}" : "#{_left}*#{vname}"
            end
          end

          "(#{_left})#{_right}"
        }
      end

      # focal variable assignment
      # lormat: [nd_vid](lvar) = [nd_value]
      # example: x = foo
      def NODE_LASGN(node, opt = {})
        node.children.then { |vid, value|
          _value = unparse(value, opt)
          if value == :NODE_SPECIAL_REQUIRED_KEYWORD
            "#{vid}:"
          elsif opt.delete(:KW_ARG)
            "#{vid}:#{value&.then { |it| " #{unparse(it, opt)}" }}"
          elsif value.nil? || (_value).empty?
            "#{vid}"
          elsif opt.delete(:expand_LASGN)
            "#{vid} = #{_value}"
          elsif value.type == :ERRINFO
            "=> #{vid}"
          else
            "(#{vid} = #{_value})"
          end
        }
      end

      # dynamic variable assignment (out of current scope)
      # format: [nd_vid](dvar) = [nd_value]
      # example: x = nil; 1.times { x = foo }
      def NODE_DASGN(node, opt = {})
        node.children.then { |vid, value|
          if value
            "(#{vid} = #{unparse(value, opt)})"
          else
            # Support: `hoge(a = 1) { a, b = c }`
            "#{vid}"
          end
        }
      end

      # dynamic variable assignment (in current scope)
      # format: [nd_vid](current dvar) = [nd_value]
      # example: 1.times { x = foo }
      def NODE_DASGN_CURR(node, opt = {})
        node.children.then { |vid, value|
          if value == :NODE_SPECIAL_REQUIRED_KEYWORD
            "#{vid}:"
          elsif opt.delete(:KW_ARG)
            "#{vid}:#{value&.then { |it| " #{unparse(it, opt)}" }}"
          elsif value.nil?
            "#{vid}"
          elsif opt.delete(:expand_DASGN_CURR)
            "#{vid} = #{unparse(value, opt)}"
          else
            "(#{vid} = #{unparse(value, opt)})"
          end
        }
      end

      # instance variable assignment
      # format: [nd_vid](ivar) = [nd_value]
      # example: @x = foo
      def NODE_IASGN(node, opt = {})
        node.children.then { |vid, value|
          if value
            "(#{vid} = #{unparse(value, opt)})"
          else
            # Support: `hoge(@a = 1) { @a, b = c }`
            "#{vid}"
          end
        }
      end

      # class variable assignment
      # format: [nd_vid](cvar) = [nd_value]
      # example: @@x = foo
      # nd_vid, "class variable"
      def NODE_CVASGN(node, opt = {})
        node.children.then { |vid, value|
          if value
            "(#{vid} = #{unparse(value, opt)})"
          else
            # Support: `hoge(@@a = 1) { @@a, b = c }`
            "#{vid}"
          end
        }
      end

      # global variable assignment
      # format: [nd_entry](gvar) = [nd_value]
      # example: $x = foo
      def NODE_GASGN(node, opt = {})
        node.children.then { |vid, value|
          if value
            "(#{vid} = #{unparse(value, opt)})"
          else
            # Support: `hoge($a = 1) { $a, b = c }`
            "#{vid}"
          end
        }
      end

      # constant declaration
      # format: [nd_else]::[nd_vid](constant) = [nd_value]
      # example: X = foo
      def NODE_CDECL(node, opt = {})
        node.children.then { |else_, vid, value|
          rvalue = Symbol === vid ? value : (value || vid)
          if rvalue
            "(#{unparse(else_, opt)} = #{unparse(rvalue, opt)})"
          else
            "#{unparse(else_, opt)}"
          end
        }
      end

      # array assignment with operator
      # format: [nd_recv] [ [nd_args->nd_head] ] [nd_mid]= [nd_args->nd_body]
      # example: ary[1] += foo
      def NODE_OP_ASGN1(node, opt = {})
        node.children.then { |recv, op, head, mid|
          "(#{unparse(recv, opt)}[#{unparse(head, opt.merge(expand_ARRAY: true))}] #{op}= #{unparse(mid, opt.merge(expand_ARRAY: true))})"
        }
      end

      # attr assignment with operator
      # format: [nd_recv].[attr] [nd_next->nd_mid]= [nd_value]
      #           where [attr]: [nd_next->nd_vid]
      # example: struct.field += foo
      def NODE_OP_ASGN2(node, opt = {})
        raise NoImplemented, "Non supported `struct.field += foo`."
      end

      # assignment with && operator
      # format: [nd_head] &&= [nd_value]
      # example: foo &&= bar
      def NODE_OP_ASGN_AND(node, opt = {})
        node.children.then { |head, op, value|
          # MEMO: implement `foo &&= bar` to `(foo = (foo && bar))`
          #       but, AST is not equal
          # value_ = value.children.then { |left, right|
          #   "(#{unparse(left, opt)} && #{unparse(right, opt)})"
          # }
          # "(#{unparse(head)} = #{value_})"
          value.children.then { |left, right|
            "(#{unparse(left, opt)} &&= #{unparse(right, opt)})"
          }
        }
      end

      # assignment with || operator
      # format: [nd_head] ||= [nd_value]
      # example: foo ||= bar
      def NODE_OP_ASGN_OR(node, opt = {})
        node.children.then { |head, op, value|
          value.children.then { |left, right|
            "(#{unparse(left, opt)} ||= #{unparse(right, opt)})"
          }
        }
      end

      # constant declaration with operator
      # format: [nd_head](constant) [nd_aid]= [nd_value]
      # example: A::B ||= 1
      def NODE_OP_CDECL(node, opt = {})
        node.children.then { |head, aid, value|
          "(#{unparse(head, opt)} #{aid}= #{unparse(value, opt)})"
        }
      end

      # method invocation
      # format: [nd_recv].[nd_mid]([nd_args])
      # example: obj.foo(1)
      def NODE_CALL(node, opt = {})
        node.children.then { |receiver, mid, args|
          "#{unparse(receiver, opt)}.#{unparse(mid, opt)}(#{unparse(args, opt.merge(expand_ARRAY: true))})"
        }
      end

      # method invocation
      # format: [nd_recv] [nd_mid] [nd_args]
      # example: foo + bar
      def NODE_OPCALL(node, opt = {})
        node.children.then { |left, op, right|
          # Support !hoge
          if right == nil
            "(#{op.to_s.delete_suffix("@")}#{unparse(left, opt)})"
          else
            "(#{unparse(left, opt)} #{op} #{unparse(right, opt.merge(expand_ARRAY: true))})"
          end
        }
      end

      # function call
      # format: [nd_mid]([nd_args])
      # example: foo(1)
      def NODE_FCALL(node, opt = {})
        node.children.then { |mid, args|
          # Support `self[key]`
          if mid == :[]
            "self[#{unparse(args, opt.merge(expand_ARRAY: true))}]"
          else
            "#{unparse(mid, opt)}(#{unparse(args, opt.merge(expand_ARRAY: true))})"
          end
        }
      end

      # function call with no argument
      # format: [nd_mid]
      # example: foo
      def NODE_VCALL(node, opt = {})
        node.children.first.to_s
      end

      # safe method invocation
      # format: [nd_recv]&.[nd_mid]([nd_args])
      # example: obj&.foo(1)
      def NODE_QCALL(node, opt = {})
        node.children.then { |receiver, mid, args|
          "#{unparse(receiver, opt)}&.#{unparse(mid, opt)}(#{unparse(args, opt.merge(expand_ARRAY: true))})"
        }
      end

      # super invocation
      # format: super [nd_args]
      # example: super 1
      def NODE_SUPER(node, opt = {})
        node.children.then { |args, |
          "super(#{unparse(args, opt.merge(expand_ARRAY: true))})"
        }
      end

      # super invocation with no argument
      # format: super
      # example: super
      def NODE_ZSUPER(node, opt = {})
        "super"
      end

      # list constructor
      # format: [ [nd_head], [nd_next].. ] (length: [nd_alen])
      # example: [1, 2, 3]
      def NODE_ARRAY(node, opt = {})
        node.children.then { |*args, _nil|
          if opt[:expand_ARRAY]
            "#{args.map(&_unparse(opt.except(:expand_ARRAY))).join(", ")}"
          else
            "[#{args.map(&_unparse(opt)).join(", ")}]"
          end
        }
      end

      # return arguments
      # format: [ [nd_head], [nd_next].. ] (length: [nd_alen])
      # example: return 1, 2, 3
      def NODE_VALUES(node, opt = {})
        node.children[0..-2].map(&_unparse(opt)).join(", ")
      end

      # empty list constructor
      # format: []
      # example: []
      def NODE_ZARRAY(node, opt = {})
        "[]"
      end

      # keyword arguments
      # format: nd_head
      # example: a: 1, b: 2
      # or
      # hash constructor
      # format: { [nd_head] }
      # example: { 1 => 2, 3 => 4 }
      def NODE_HASH(node, opt = {})
        node.children.then { |head,|
          if head.nil?
            "{}"
          # Support `foo(**kwd)`
          elsif head.children.first.nil?
            "**#{unparse(head.children[1], opt)}"
          else
            result = (head).children[0..-2].map(&_unparse(opt)).each_slice(2).map { |key, value|
                "#{key} => #{value}"
              }.join(", ")
            if opt[:expand_HASH]
              "#{result}"
            else
              "{ #{result} }"
            end
          end
        }
      end

      # yield invocation
      # format: yield [nd_head]
      # example: yield 1
      def NODE_YIELD(node, opt = {})
        node.children.then { |head,|
          "yield(#{unparse(head, opt.merge(expand_ARRAY: true))})"
        }
      end

      # local variable reference
      # format: [nd_vid](lvar)
      # example: x
      def NODE_LVAR(node, opt = {})
        # Support pattern match
        # in ^expr
        if opt[:pattern_match_LVAR]
          "^#{node.children.first}"
        else
          "#{node.children.first}"
        end
      end

      # dynamic variable reference
      # format: [nd_vid](dvar)
      # example: 1.times { x = 1; x }
      def NODE_DVAR(node, opt = {})
        node.children.then { |vid, dvar|
          vid.to_s
        }
      end

      # instance variable reference
      # format: [nd_vid](ivar)
      # example: @x
      def NODE_IVAR(node, opt = {})
        node.children.then { |vid,|
          vid.to_s
        }
      end

      # constant reference
      # format: [nd_vid](constant)
      # example: X
      def NODE_CONST(node, opt = {})
        node.children.then { |vid,|
          "#{vid}"
        }
      end

      # class variable reference
      # format: [nd_vid](cvar)
      # example: @@x
      def NODE_CVAR(node, opt = {})
        node.children.then { |vid,|
          vid.to_s
        }
      end

      # global variable reference
      # format: [nd_entry](gvar)
      # example: $x
      def NODE_GVAR(node, opt = {})
        node.children.then { |vid,|
          vid.to_s
        }
      end

      # nth special variable reference
      # format: $[nd_nth]
      # example: $1, $2, ..
      def NODE_NTH_REF(node, opt = {})
        node.children.then { |vid,|
          vid.to_s
        }
      end

      # back special variable reference
      # format: $[nd_nth]
      # example: $&, $`, $', $+
      def NODE_BACK_REF(node, opt = {})
        node.children.then { |vid,|
          vid.to_s
        }
      end

      # match expression (against $_ implicitly)
      # format: [nd_lit] (in condition)
      # example: if /foo/; foo; end
      def NODE_MATCH(node, opt = {})
        node.children.then { |lit,|
          lit.inspect
        }
      end

      # match expression (regexp first)
      # format: [nd_recv] =~ [nd_value]
      # example: /foo/ =~ 'foo'
      def NODE_MATCH2(node, opt = {})
        node.children.then { |recv, value|
          "#{unparse(recv, opt)} =~ #{unparse(value, opt)}"
        }
      end

      # match expression (regexp second)
      # format: [nd_recv] =~ [nd_value]
      # example: 'foo' =~ /foo/
      def NODE_MATCH3(node, opt = {})
        node.children.then { |recv, value|
          "#{unparse(value, opt)} =~ #{unparse(recv, opt)}"
        }
      end

      # literal
      # format: [nd_lit]
      # example: 1, /foo/
      def NODE_LIT(node, opt = {})
        node.children.first.inspect
      end

      # string literal
      # format: [nd_lit]
      # example: 'foo'
      def NODE_STR(node, opt = {})
        node.children.first.dump
        if opt.delete(:ignore_quote_STR)
          node.children.first.to_s.escape
        else
          node.children.first.dump
        end
      end

      # xstring literal
      # format: [nd_lit]
      # example: `foo`
      def NODE_XSTR(node, opt = {})
        node.children.then { |lit,|
          "`#{lit.to_s}`"
        }
      end

      # once evaluation
      # format: [nd_body]
      # example: /foo#{ bar }baz/o
      def NODE_ONCE(node, opt = {})
        "#{NODE_DREGX(node.children.first, opt)}o"
      end

      # string literal with interpolation
      # format: [nd_lit]
      # example: \"foo#{ bar }baz\"
      def NODE_DSTR(node, opt = {})
        "\"#{without_DSTR_quote(node, opt)}\""
      end
      def without_DSTR_quote(node, opt)
        node.children.then { |prefix, lit, suffix|
          suffix_ = suffix&.children&.compact&.map { |it|
            if it.type == :STR
              unparse(it, opt.merge(ignore_quote_STR: true))
            else
              unparse(it, opt.merge(ignore_quote_STR: false))
            end
          }&.join
          "#{prefix&.escape}#{unparse(lit, opt)}#{suffix_}"
        }
      end

      # xstring literal with interpolation
      # format: [nd_lit]
      # example: `foo#{ bar }baz`
      def NODE_DXSTR(node, opt = {})
        "`#{without_DSTR_quote(node, opt)}`"
      end

      # regexp literal with interpolation
      # format: [nd_lit]
      # example: /foo#{ bar }baz/
      def NODE_DREGX(node, opt = {})
        node.children.then { |prefix, lit, suffix|
          suffix_ = suffix&.children&.compact&.map { |it|
            unparse(it, opt).then do |it|
              it.undump
            rescue
              it
            end
          }&.join
          "/#{prefix}#{unparse(lit, opt)}#{suffix_}/"
        }
      end

      # symbol literal with interpolation
      # format: [nd_lit]
      # example: :\"foo#{ bar }baz\"
      def NODE_DSYM(node, opt = {})
        ":#{NODE_DSTR(node, opt)}"
      end

      # interpolation expression
      # format: \"..#{ [nd_lit] }..\"
      # example: \"foo#{ bar }baz\"
      def NODE_EVSTR(node, opt = {})
        node.children.then { |lit,|
          "\#{#{unparse(lit, opt)}}"
        }
      end

      # splat argument following arguments
      # format: ..(*[nd_head], [nd_body..])
      # example: foo(*ary, post_arg1, post_arg2)
      def NODE_ARGSCAT(node, opt = {})
        node.children.then { |head, body|
          if body.type == :ARRAY
            "#{unparse(head, opt)}, #{unparse(body, opt)}"
          else
            "#{unparse(head, opt)}, *#{unparse(body, opt)}"
          end
        }
      end

      # splat argument following one argument
      # format: ..(*[nd_head], [nd_body])
      # example: foo(*ary, post_arg)
      def NODE_ARGSPUSH(node, opt = {})
        node.children.then { |head, body|
          "#{unparse(head, opt)}, #{unparse(body, opt)}"
        }
      end

      # splat argument
      # format: *[nd_head]
      # example: foo(*ary)
      def NODE_SPLAT(node, opt = {})
        node.children.then { |head,|
          "*#{unparse(head, opt.merge(expand_ARRAY: false))}"
        }
      end

      # arguments with block argument
      # format: ..([nd_head], &[nd_body])
      # example: foo(x, &blk)
      def NODE_BLOCK_PASS(node, opt = {})
        node.children.then { |head, body|
          "#{head&.then { |it| "#{unparse(it, opt)}, " }}&#{unparse(body, opt)}"
        }
      end

      # method definition
      # format: def [nd_mid] [nd_defn]; end
      # example: def foo; bar; end
      def NODE_DEFN(node, opt = {})
        node.children.then { |mid, defn|
          info = unparse_NODE_SCOPE(defn, opt)
          <<~EOS.chomp
            def #{mid}(#{info[:args]})
              #{info[:body]}
            end
          EOS
        }
      end

      # singleton method definition
      # format: def [nd_recv].[nd_mid] [nd_defn]; end
      # example: def obj.foo; bar; end
      def NODE_DEFS(node, opt = {})
        node.children.then { |recv, mid, defn|
          info = unparse_NODE_SCOPE(defn, opt)
          <<~EOS.chomp
            def #{unparse(recv, opt)}.#{mid}(#{info[:args]})
              #{info[:body]}
            end
          EOS
        }
      end

      # method alias statement
      # format: alias [nd_1st] [nd_2nd]
      # example: alias bar foo
      def NODE_ALIAS(node, opt = {})
        node.children.then { |nd_1st, nd_2nd|
          "alias #{unparse(nd_1st, opt)} #{unparse(nd_2nd, opt)}"
        }
      end

      # global variable alias statement
      # format: alias [nd_alias](gvar) [nd_orig](gvar)
      # example: alias $y $x
      def NODE_VALIAS(node, opt = {})
        node.children.then { |nd_1st, nd_2nd|
          "alias #{nd_1st} #{nd_2nd}"
        }
      end

      # method undef statement
      # format: undef [nd_undef]
      # example: undef foo
      def NODE_UNDEF(node, opt = {})
        node.children.then { |nd_undef,|
          "undef #{unparse(nd_undef, opt)}"
        }
      end

      # class definition
      # format: class [nd_cpath] < [nd_super]; [nd_body]; end
      # example: class C2 < C; ..; end
      def NODE_CLASS(node, opt = {})
        node.children.then { |cpath, super_, body|
          <<~EOS.chomp
          class #{unparse(cpath, opt)}#{super_&.then { |it| " < #{unparse(it, opt)}" } }
            #{unparse(body, opt.merge(without_BEGIN: true))}
          end
          EOS
        }
      end

      # module definition
      # format: module [nd_cpath]; [nd_body]; end
      # example: module M; ..; end
      def NODE_MODULE(node, opt = {})
        node.children.then { |cpath, body|
          <<~EOS.chomp
          module #{unparse(cpath, opt)}
            #{unparse(body, opt.merge(without_BEGIN: true))}
          end
          EOS
        }
      end

      # singleton class definition
      # format: class << [nd_recv]; [nd_body]; end
      # example: class << obj; ..; end
      def NODE_SCLASS(node, opt = {})
        node.children.then { |recv, body|
          <<~EOS.chomp
          class << #{unparse(recv, opt)}
            #{unparse(body, opt.merge(without_BEGIN: true))}
          end
          EOS
        }
      end

      # scoped constant reference
      # format: [nd_head]::[nd_mid]
      # example: M::C
      def NODE_COLON2(node, opt = {})
        node.children.then { |head, mid|
          "#{unparse(head, opt)&.then { |it| "#{unparse(head, opt)}::" }}#{mid}"
        }
      end

      # top-level constant reference
      # format: ::[nd_mid]
      # example: ::object
      def NODE_COLON3(node, opt = {})
        node.children.then { |mid,|
          "::#{mid}"
        }
      end

      # range constructor (incl.)
      # format: [nd_beg]..[nd_end]
      # example: 1..5
      def NODE_DOT2(node, opt = {})
        node.children.then { |beg, end_|
          "(#{unparse(beg, opt)}..#{unparse(end_, opt)})"
        }
      end

      # range constructor (excl.)
      # format: [nd_beg]...[nd_end]
      # example: 1...5
      def NODE_DOT3(node, opt = {})
        node.children.then { |beg, end_|
          "(#{unparse(beg, opt)}...#{unparse(end_, opt)})"
        }
      end

      # flip-flop condition (incl.)
      # format: [nd_beg]..[nd_end]
      # example: if (x==1)..(x==5); foo; end
      def NODE_FLIP2(node, opt = {})
        node.children.then { |beg, end_|
          "(#{unparse(beg, opt)})..(#{unparse(end_, opt)})"
        }
      end

      # flip-flop condition (excl.)
      # format: [nd_beg]...[nd_end]
      # example: if (x==1)...(x==5); foo; end
      def NODE_FLIP3(node, opt = {})
        node.children.then { |beg, end_|
          "(#{unparse(beg, opt)})...(#{unparse(end_, opt)})"
        }
      end

      # self
      # format: self
      # example: self
      def NODE_SELF(*)
        "self"
      end

      # nil
      # format: nil
      # example: nil
      def NODE_NIL(*)
        "nil"
      end

      # true
      # format: true
      # example: true
      def NODE_TRUE(*)
        "true"
      end

      # false
      # format: false
      # example: false
      def NODE_FALSE(*)
        "false"
      end

      # virtual reference to $!
      # format: rescue => id
      # example: rescue => id
      def NODE_ERRINFO(node, opt = {})
        "rescue"
      end

      # defined? expression
      # format: defined?([nd_head])
      # example: defined?(foo)
      def NODE_DEFINED(node, opt = {})
        node.children.then { |head,|
          "defined?(#{unparse(head, opt)})"
        }
      end

      # post-execution
      # format: END { [nd_body] }
      # example: END { foo }
      def NODE_POSTEXE(node, opt = {})
        node.children.then { |body,|
          "END { #{unparse(body, opt)} }"
        }
      end

      # attr assignment
      # format: [nd_recv].[nd_mid] = [nd_args]
      # example: struct.field = foo
      def NODE_ATTRASGN(node, opt = {})
        node.children.then { |recv, mid, args|
          if mid == :[]=
            *args_, right, _ = args.children
            "#{unparse(recv, opt)}[#{args_.map(&_unparse(opt.merge(expand_ARRAY: true))).join(", ")}] = #{unparse(right, opt.merge(expand_ARRAY: true))}"
          else
            "#{unparse(recv, opt)}.#{mid}#{unparse(args, opt.merge(expand_ARRAY: true))}"
          end
        }
      end

      # lambda expression
      # format: -> [nd_body]
      # example: -> { foo }
      def NODE_LAMBDA(node, opt = {})
        node.children.then { |scope,|
          result = unparse_NODE_SCOPE(scope, opt)
          "-> (#{result[:args]}) { #{result[:body]} }"
        }
      end

      # optional arguments
      # format: def method_name([nd_body=some], [nd_next..])
      # example: def foo(a, b=1, c); end
      def NODE_OPT_ARG(node, opt = {})
        node.children.map(&_unparse(opt.merge(expand_DASGN_CURR: true, expand_LASGN: true))).compact.join(", ")
      end
      def unparse_NODE_OPT_ARG(node, opt = {})
        node.children.then { |head, children|
          [unparse(head, opt)] + (children ? unparse_NODE_OPT_ARG(children, opt) : [])
        }
      end

      # keyword arguments
      # format: def method_name([nd_body=some], [nd_next..])
      # example: def foo(a:1, b:2); end
      def NODE_KW_ARG(node, opt = {})
        node.children[0..-1].map(&_unparse(opt.merge(KW_ARG: true))).compact.join(", ")
      end
      def unparse_NODE_KW_ARG(node, opt = {})
        node.children.then { |head, children|
          [unparse(head, opt)] + (children ? unparse_NODE_KW_ARG(children, opt) : [])
        }
      end

      # post arguments
      # format: *[nd_1st], [nd_2nd..] = ..
      # example: a, *rest, z = foo
      def NODE_POSTARG(node, opt = {})
        node.children.then { |_1st, _2nd|
          "#{unparse(_1st, opt)}, #{unparse(_2nd, opt.merge(expand_ARRAY: true))}"
        }
      end

      # method parameters
      # format: def method_name(.., [nd_opt=some], *[nd_rest], [nd_pid], .., &[nd_body])
      # example: def foo(a, b, opt1=1, opt2=2, *rest, y, z, &blk); end
      def NODE_ARGS(node, opt_ = {})
        (
          _, # pre_num
          _, # pre_init
          opt,
          _, # first_post
          _, # post_num
          _, # post_init
          _, # rest
          _, # kw
          _, # kwrest
          _, # block
        ) = node.children
        "#{unparse(opt, opt_)}#{unparse(kw, opt_)}"
      end
      def unparse_NODE_ARGS(node, opt = {})
        %i(
          pre_num
          pre_init
          opt
          first_post
          post_num
          post_init
          rest
          kw
          kwrest
          block
        ).map.with_index { |key, i| [key, node.children[i]] }.to_h.then { |info|
          info.merge(
            unparsed_pre_init: info[:pre_init]&.then { |node|
              node.type == :BLOCK ? node.children.map(&_unparse(opt)) : [unparse(node, opt)]
            } || [],
            unparsed_post_init: info[:post_init]&.then { |node|
              node.type == :BLOCK ? node.children.map(&_unparse(opt)) : [unparse(node, opt)]
            } || [],
            unparsed_opt: info[:opt]&.then { |it| unparse_NODE_OPT_ARG(it, opt.merge(expand_DASGN_CURR: true, expand_LASGN: true)) } || [],
            unparsed_rest: unparse(info[:rest], opt)&.then { |it|
              if it == :NODE_SPECIAL_EXCESSIVE_COMMA
                [" "]
              else
                ["*#{it}"]
              end
            } || [],
            unparsed_kw: info[:kw]&.then { |it| unparse_NODE_KW_ARG(it, opt.merge(expand_DASGN_CURR: true, expand_LASGN: true, KW_ARG: true)) } || [],
            unparsed_kwrest: info[:kwrest]&.then { |it| "**#{unparse(it, opt)}" },
          )
        }
      end

      # new scope
      # format: [nd_tbl]: local table, [nd_args]: arguments, [nd_body]: body
      def NODE_SCOPE(node, opt = {})
        result = unparse_NODE_SCOPE(node, opt)
        if result[:args].empty?
          "#{result[:body]}"
        elsif opt[:ITER]
          "|#{result[:args]}| #{result[:body]}"
        else
          "|#{result[:args]}| #{result[:body]}"
        end
      end
      def unparse_NODE_SCOPE(node, opt = {})
        node.children.then { |tbl, args, body|
          break { args: "", body: unparse(body, opt) } if args.nil?

  #         info = unparse_NODE_ARGS(args, opt)
          info = unparse_NODE_ARGS(args, opt.merge(_NODE_MASGN: true))

          # Support proc { |**| }
          break { args: "**", body: unparse(body, opt) } if tbl == [nil] && info[:kwrest]

          pre_args = []
          [info[:pre_num], info[:unparsed_pre_init]&.size || 0].max.times {
            tbl.shift.then { |it|
              pre_args << (it ? it : info[:unparsed_pre_init].shift)
            }
          }

          # skip to opt args
          # e.g. a = 1, b = 2
          tbl = tbl.drop(info[:unparsed_opt].count)

          # skip to rest args
          # e.g. *a
          tbl = tbl.drop(info[:unparsed_rest].count)

          star = nil
          tbl.take_while(&:nil?).tap { |nils|
            if info[:unparsed_post_init].count < nils.count
              star = "*"
              tbl = tbl.drop(1)
            end
          }

          post_args = []
          [info[:post_num], info[:unparsed_post_init]&.size || 0].max.times {
            tbl.shift.then { |it|
              post_args << (it ? it : info[:unparsed_post_init].shift)
            }
          }

          # skip to kw args
          # e.g. a:, b: c: 1
          tbl = tbl.drop(info[:unparsed_kw].count.tap { |count| break count + 1 if count != 0 })

          if info[:unparsed_kwrest] == "**" && tbl.fetch(0, 1) != nil
            kwrest = ""
          else
            kwrest = info[:unparsed_kwrest]
          end

          params = [
            pre_args,
            info[:unparsed_opt].join(", "),
            info[:unparsed_rest].join(", "),
            star,
            post_args,
            info[:unparsed_post_init].join(", "),
            info[:unparsed_kw].join(", "),
            kwrest,
            info[:block]&.then { |str| "&#{str}" },
          ].compact.reject(&:empty?).join(", ")

          { args: params, body: unparse(body, opt) }
        }
      end

      def NODE_ARGS_AUX(node, opt = {})
        ""
      end

      def NODE_LAST(node, opt = {})
        ""
      end
    end

    module Ruby2_6_0
      include Base
    end

    module Ruby2_7_0
      include Ruby2_6_0

      private

      # case statement (pattern matching)
      # format: case [nd_head]; [nd_body]; end
      # example: case x; in 1; foo; in 2; bar; else baz; end
      def NODE_CASE3(node, opt = {})
        node.children.then { |head, body, else_|
          <<~EOS.chomp
          case #{unparse(head, opt)}
          #{unparse(body, opt)}#{else_ ? "\nelse\n#{unparse(else_, opt)}" : ""}
          end
          EOS
        }
      end

      # list constructor
      # format: [ [nd_head], [nd_next].. ] (length: [nd_alen])
      # example: [1, 2, 3]
      def NODE_LIST(node, opt = {})
        NODE_ARRAY(node, opt)
      end

      def NODE_ZLIST(node, opt = {})
        NODE_ZARRAY(node, opt)
      end

      def NODE_IN(node, opt = {})
        node.children.then { |head, body, next_|
          <<~EOS.chomp
          in #{unparse(head, opt.merge(expand_ARRAY: true))}
            #{unparse(body, opt)}
          #{next_&.type == :IN || next_.nil? ? unparse(next_, opt) : "else\n  #{unparse(next_, opt)}"}
          EOS
        }
      end

      # splat argument following arguments
      # format: ..(*[nd_head], [nd_body..])
      # example: foo(*ary, post_arg1, post_arg2)
      def NODE_ARGSCAT(node, opt = {})
        node.children.then { |head, body|
          if body.type == :LIST
            "#{unparse(head, opt)}, #{unparse(body, opt)}"
          else
            "#{unparse(head, opt)}, *#{unparse(body, opt)}"
          end
        }
      end

      # array pattern
      # format: [nd_pconst]([pre_args], ..., *[rest_arg], [post_args], ...)
      def NODE_ARYPTN(node, opt = {})
        node.children.then { |pconst, pre, rest, post|
          # e.g. in Array[a, b]
          pconst_ = unparse(pconst, opt) if pconst

          opt_flags = { expand_ARRAY: true, expand_HASH: true, pattern_match_OR: true, pattern_match_LVAR: true }
          pre_ = unparse(pre, opt.merge(opt_flags))
          if rest == :NODE_SPECIAL_NO_NAME_REST
            rest_ = "*"
          elsif rest
            rest_ = "*#{unparse(rest, opt.merge(opt_flags))}"
          end
          post_ = unparse(post, opt.merge(opt_flags))
          "#{pconst_}[#{[pre_, rest_, post_].compact.join(", ")}]"
        }
      end

      # hash pattern
      # format: [nd_pconst]([nd_pkwargs], ..., **[nd_pkwrestarg])
      def NODE_HSHPTN(node, opt = {})
        # :TODO:
        node
      end
    end

    module Ruby2_7_2
      include Ruby2_7_0

      private

      # attr assignment with operator
      # format: [nd_recv].[attr] [nd_next->nd_mid]= [nd_value]
      #           where [attr]: [nd_next->nd_vid]
      # example: struct.field += foo
      def NODE_OP_ASGN2(node, opt = {})
        node.children.then { |recv, _, attr, op, mid|
          "#{unparse(recv, opt)}.#{attr} #{op}= #{unparse(mid, opt)}"
        }
      end
    end

    module Ruby3_0_0
      include Ruby2_7_2

      # string literal with interpolation
      # format: [nd_lit]
      # example: \"foo#{ bar }baz\"
      def NODE_DSTR(node, opt = {})
        node.children.then { |prefix, lit, suffix|
          # Add support `"foo#{ "hoge" }baz"`
          if lit.nil? && suffix.nil?
            "\"\#{#{prefix.dump}\}\""
          else
            super
          end
        }
      end
    end

    case RUBY_VERSION
    when ("2.6.0"..."2.7.0")
      VERSION = Ruby2_6_0
    when ("2.7.0"..."2.7.2")
      VERSION = Ruby2_7_0
    when ("2.7.2"..."3.0.0")
      VERSION = Ruby2_7_2
    when ("3.0.0"...)
      VERSION = Ruby3_0_0
    else
      railse "Not implemented Ruby version #{RUBY_VERSION}"
    end

    class Caller
      include VERSION
    end

    def self.unparse(node)
      Caller.new.unparse(node)
    end
  end
end
