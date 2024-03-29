[![Ruby CI](https://github.com/osyo-manga/gem-rensei/actions/workflows/rensei.yml/badge.svg)](https://github.com/osyo-manga/gem-rensei/actions/workflows/rensei.yml)

# Rensei

Unparse from `RubyVM::AbstractSyntaxTree::Node` to Ruby code.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'rensei'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install rensei

## Usage

```ruby
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
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/osyo-manga/gem-rensei.


## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
