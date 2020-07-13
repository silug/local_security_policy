# frozen_string_literal: true

require 'spec_helper_acceptance'

describe 'local_security_policy' do
  context 'with policies in hiera' do
    let(:manifest) { 'include local_security_policy' }

    it 'is expected to apply with no errors' do
      fixtures = File.join(__dir__, '..', '..', 'fixtures', 'acceptance')

      hosts.each do |host|
        envpath = on(host, 'puppet config print environmentpath').output.strip
        env = on(host, 'puppet config print environment').output.strip

        scp_to(host, "#{fixtures}/hiera.yaml", "#{envpath}/#{env}")
        scp_to(host, "#{fixtures}/layer1.yaml", "#{envpath}/#{env}/data")
        scp_to(host, "#{fixtures}/layer2.yaml", "#{envpath}/#{env}/data")
      end

      # Run twice to test idempotency
      apply_manifest(manifest, 'catch_failures' => true)
      apply_manifest(manifest, 'catch_changes' => true)
    end

    it 'sets values correctly' do
      # This tests that policies in Hiera are merged and applied.
      on hosts, 'Secedit /Export /Areas SecurityPolicy /CFG C:\secedit.txt'
      hosts.each do |host|
        value = on(host, 'type C:\secedit.txt')
        expect(value.output).to match(%r{^PasswordHistorySize\s*=\s*30$})
      end

      hosts.each do |host|
        value = on(host, 'auditpol /get /category:*')
        expect(value.output).to match(%r{^\s*Credential Validation\s*Success$})
      end
    end
  end
end
