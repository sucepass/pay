$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "pay/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name = "pay"
  s.version = Pay::VERSION
  s.authors = ["Jason Charnes", "Chris Oliver"]
  s.email = ["jason@thecharnes.com", "excid3@gmail.com"]
  s.homepage = "https://github.com/jasoncharnes/pay"
  s.summary = "A Ruby on Rails subscription engine."
  s.description = "A Ruby on Rails subscription engine."
  s.license = "MIT"

  s.files = Dir[
    "{app,config,db,lib}/**/*",
    "MIT-LICENSE",
    "Rakefile",
    "README.md"
  ]

  s.add_dependency "rails", ">= 4.2"

  s.add_development_dependency "braintree", ">= 2.92.0", "< 4.0"
  s.add_development_dependency "stripe", ">= 2.8"
  s.add_development_dependency "stripe_event", "~> 2.3"
  s.add_development_dependency "paddle_pay", "~> 0.0.1"

  s.add_development_dependency "minitest-rails", ">= 6", "< 7.0"
  s.add_development_dependency "mocha"
  s.add_development_dependency "standardrb"
  s.add_development_dependency "vcr"
  s.add_development_dependency "webmock"
end
