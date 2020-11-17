# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'activerecord/jsonapi_update/version'

Gem::Specification.new do |spec|
  spec.name          = 'activerecord-jsonapi_update'
  spec.version       = ActiveRecord::JsonApiUpdate::VERSION
  spec.authors       = ['Aleck Greenham']
  spec.email         = ['greenhama13@gmail.com']
  spec.summary       = 'Update records and their associations consistent with JSON API specification.'
  spec.description   = 'The JSON API specification requires associated resources included in a PATCH request, ' \
                       'if provided, to completely replace those that already exist. ActiveRecord\'s #update ' \
                        'method only does that in some circumstances. activerecord-jsonapi_update handles the rest of them.'
  spec.homepage      = 'https://github.com/greena13/activerecord-jsonapi_update'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']
  spec.required_ruby_version = '>= 1.8.7'

  spec.add_dependency 'activerecord', '>= 3.0.0'
end
