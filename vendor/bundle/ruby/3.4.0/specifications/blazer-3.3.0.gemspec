# -*- encoding: utf-8 -*-
# stub: blazer 3.3.0 ruby lib

Gem::Specification.new do |s|
  s.name = "blazer".freeze
  s.version = "3.3.0".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Andrew Kane".freeze]
  s.date = "2025-04-13"
  s.email = "andrew@ankane.org".freeze
  s.homepage = "https://github.com/ankane/blazer".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 3.2".freeze)
  s.rubygems_version = "3.6.2".freeze
  s.summary = "Explore your data with SQL. Easily create charts and dashboards, and share them with your team.".freeze

  s.installed_by_version = "3.6.9".freeze

  s.specification_version = 4

  s.add_runtime_dependency(%q<railties>.freeze, [">= 7.1".freeze])
  s.add_runtime_dependency(%q<activerecord>.freeze, [">= 7.1".freeze])
  s.add_runtime_dependency(%q<chartkick>.freeze, [">= 5".freeze])
  s.add_runtime_dependency(%q<safely_block>.freeze, [">= 0.4".freeze])
  s.add_runtime_dependency(%q<csv>.freeze, [">= 0".freeze])
end
