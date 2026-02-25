# -*- encoding: utf-8 -*-
# stub: norairrecord 0.5.1 ruby lib

Gem::Specification.new do |s|
  s.name = "norairrecord".freeze
  s.version = "0.5.1".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["nora".freeze]
  s.bindir = "exe".freeze
  s.date = "2025-11-18"
  s.description = "screwed a cookie to the tabel".freeze
  s.email = ["nora@hcb.pizza".freeze]
  s.homepage = "https://github.com/24c02/norairrecord".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.2".freeze)
  s.rubygems_version = "3.5.16".freeze
  s.summary = "Airtable client".freeze

  s.installed_by_version = "3.6.9".freeze

  s.specification_version = 4

  s.add_runtime_dependency(%q<faraday>.freeze, [">= 1.0".freeze, "< 3.0".freeze])
  s.add_runtime_dependency(%q<net-http-persistent>.freeze, [">= 0".freeze])
  s.add_runtime_dependency(%q<faraday-net_http_persistent>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<bundler>.freeze, ["~> 2".freeze])
  s.add_development_dependency(%q<rake>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<rspec>.freeze, ["~> 3.0".freeze])
end
