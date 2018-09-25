
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "zaius/version"

Gem::Specification.new do |spec|
  spec.name          = "zaius"
  spec.version       = Zaius::VERSION
  spec.authors       = ["Chris Anderson"]
  spec.email         = ["chris@galleyfoods.com"]

  spec.summary       = %q{Zaius api ruby gem.}
  spec.homepage      = "https://www.galleyfoods.com"
  spec.license       = "MIT"

  spec.add_dependency("faraday", "~> 0.10")

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.16"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "byebug"
end
