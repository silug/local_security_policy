# frozen_string_literal: true

require 'puppetlabs_spec_helper/module_spec_helper'
require 'rspec-puppet-facts'

require 'spec_helper_local' if File.file?(File.join(File.dirname(__FILE__), 'spec_helper_local.rb'))
require 'pathname'

include RspecPuppetFacts

# RSpec Material
fixture_path = File.expand_path(File.join(__FILE__, '..', 'fixtures'))
module_name = File.basename(File.expand_path(File.join(__FILE__, '../..')))

# Add fixture lib dirs to LOAD_PATH. Work-around for PUP-3336
if Puppet.version < '4.0.0'
  Dir["#{fixture_path}/modules/*/lib"].entries.each do |lib_dir|
    $LOAD_PATH << lib_dir
  end
end

default_hiera_config = <<-EOM
---
version: 5
hierarchy:
  - name: Custom Test Hiera
    path: "%{custom_hiera}.yaml"
  - name: "%{module_name}"
    path: "%{module_name}.yaml"
  - name: Common
    path: common.yaml
defaults:
  data_hash: yaml_data
  datadir: "stub"
EOM

default_facts = {
  puppetversion: Puppet.version,
  facterversion: Facter.version,
}

default_fact_files = [
  File.expand_path(File.join(File.dirname(__FILE__), 'default_facts.yml')),
  File.expand_path(File.join(File.dirname(__FILE__), 'default_module_facts.yml')),
]

default_fact_files.each do |f|
  next unless File.exist?(f) && File.readable?(f) && File.size?(f)

  begin
    default_facts.merge!(YAML.safe_load(File.read(f), [], [], true))
  rescue => e
    RSpec.configuration.reporter.message "WARNING: Unable to load #{f}: #{e}"
  end
end

# read default_facts and merge them over what is provided by facterdb
default_facts.each do |fact, value|
  add_custom_fact fact, value
end

# This can be used from inside your spec tests to load custom hieradata within
# any context.
#
# Example:
#
# describe 'some::class' do
#   context 'with version 10' do
#     let(:hieradata){ "#{class_name}_v10" }
#     ...
#   end
# end
#
# Then, create a YAML file at spec/fixtures/hieradata/some__class_v10.yaml.
#
# Hiera will use this file as it's base of information stacked on top of
# 'default.yaml' and <module_name>.yaml per the defaults above.
#
# Note: Any colons (:) are replaced with underscores (_) in the class name.
def set_hieradata(hieradata)
  RSpec.configure { |c| c.default_facts['custom_hiera'] = hieradata }
end

unless File.directory?(File.join(fixture_path, 'hieradata'))
  FileUtils.mkdir_p(File.join(fixture_path, 'hieradata'))
end

unless File.directory?(File.join(fixture_path, 'modules', module_name))
  FileUtils.mkdir_p(File.join(fixture_path, 'modules', module_name))
end

RSpec.configure do |c|
  c.default_facts = default_facts

  c.mock_with :rspec

  c.module_path = File.join(fixture_path, 'modules')
  c.manifest_dir = File.join(fixture_path, 'manifests')

  c.hiera_config = File.join(fixture_path, 'hieradata', 'hiera.yaml')

  # Useless backtrace noise
  backtrace_exclusion_patterns = [
    %r{spec_helper},
    %r{gems},
  ]

  c.before(:all) do
    data = YAML.safe_load(default_hiera_config)
    data.keys.each do |key|
      next unless data[key].is_a?(Hash)

      if data[key][:datadir] == 'stub'
        data[key][:datadir] = File.join(fixture_path, 'hieradata')
      elsif data[key]['datadir'] == 'stub'
        data[key]['datadir'] = File.join(fixture_path, 'hieradata')
      end
    end

    File.open(c.hiera_config, 'w') do |f|
      f.write data.to_yaml
    end
  end

  if c.respond_to?(:backtrace_exclusion_patterns)
    c.backtrace_exclusion_patterns = backtrace_exclusion_patterns
  elsif c.respond_to?(:backtrace_clean_patterns)
    c.backtrace_clean_patterns = backtrace_exclusion_patterns
  end

  c.before :each do
    # set to strictest setting for testing
    # by default Puppet runs at warning level
    Puppet.settings[:strict] = :warning
    Puppet.settings[:strict_variables] = true

    # sanitize hieradata
    if defined?(hieradata)
      set_hieradata(hieradata.tr(':', '_'))
    elsif defined?(class_name)
      set_hieradata(class_name.tr(':', '_'))
    end
  end

  c.filter_run_excluding(bolt: true) unless ENV['GEM_BOLT']
  c.after(:suite) do
  end
end

# Ensures that a module is defined
# @param module_name Name of the module
def ensure_module_defined(module_name)
  module_name.split('::').reduce(Object) do |last_module, next_module|
    last_module.const_set(next_module, Module.new) unless last_module.const_defined?(next_module, false)
    last_module.const_get(next_module, false)
  end
end

# 'spec_overrides' from sync.yml will appear below this line
