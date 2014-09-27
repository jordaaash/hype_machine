require 'rubygems/version'

module HypeMachine
  # Returns the version of the currently loaded HypeMachine as a <tt>Gem::Version</tt>
  def self.gem_version
    Gem::Version.new VERSION::STRING
  end

  module VERSION
    MAJOR = 0
    MINOR = 1
    TINY  = 1
    PRE   = 'alpha'

    STRING = [MAJOR, MINOR, TINY, PRE].compact.join('.')
  end
end
