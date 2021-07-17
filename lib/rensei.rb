require "rensei/version"
require "rensei/unparser"
require "rensei/node_to_hash"

module Rensei
  class Error < StandardError; end

  def self.unparse(code, opt = {})
    Unparser.unparse(code, opt)
  end
end
