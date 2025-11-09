require_relative "lib/ruby_agent/version"

Gem::Specification.new do |spec|
  spec.name          = "ruby_agent"
  spec.version       = RubyAgent::VERSION
  spec.authors       = ["Keith Schacht", "Matt Lindsey"]
  spec.email         = ["krschacht@gmail.com"]

  spec.summary       = "Ruby agent framework"
  spec.description   = "A framework for building AI agents in Ruby"
  spec.homepage      = "https://github.com/AllYourBot/ruby-agent"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/AllYourBot/ruby-agent"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|claude)|appveyor)})
    end
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
end
