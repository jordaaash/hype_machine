require 'hype_machine/gem_version'

module HypeMachine
  # Returns the version of the currently loaded HypeMachine as a <tt>Gem::Version</tt>
  def self.version
    gem_version
  end
end
