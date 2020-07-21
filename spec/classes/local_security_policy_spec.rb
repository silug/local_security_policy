# frozen_string_literal: true

require 'spec_helper'

describe 'local_security_policy' do
  before(:each) do
    allow(Puppet::Util::Windows::SID).to receive(:name_to_sid).with('Administrators').and_return('S-1-5-32-544')
    allow(Puppet::Util::Windows::SID).to receive(:name_to_sid).with('Network Configuration Operators').and_return('S-1-5-32-556')
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      context 'with default parameters' do
        it { is_expected.to compile.with_all_deps }
      end

      context 'with settings from params' do
        let(:params) do
          {
            'policies' => {
              'Audit account logon events' => {
                'ensure'         => 'present',
                'policy_setting' => 'AuditAccountLogon',
                'policy_type'    => 'Event Audit',
                'policy_value'   => 'Success,Failure',
              },
            },
          }
        end

        it { is_expected.to compile.with_all_deps }

        it {
          is_expected.to contain_local_security_policy('Audit account logon events').with(
            :ensure         => 'present',
            :policy_setting => 'AuditAccountLogon',
            :policy_type    => 'Event Audit',
            :policy_value   => 'Success,Failure',
          )
        }
      end

      context 'with settings from hiera' do
        let(:hieradata) { 'lsp_policies' }

        it { is_expected.to compile.with_all_deps }

        it {
          is_expected.to contain_local_security_policy('Audit account logon events').with(
            :ensure         => 'present',
            :policy_setting => 'AuditAccountLogon',
            :policy_type    => 'Event Audit',
            :policy_value   => 'Success,Failure',
          )
        }

        it {
          is_expected.to contain_local_security_policy('Generate security audits').with(
            :ensure         => 'present',
            :policy_setting => 'SeAuditPrivilege',
            :policy_type    => 'Privilege Rights',
            :policy_value   => 'Administrators,Network Configuration Operators',
          )
        }
      end

      context 'with settings from hiera and one invalid' do
        let(:hieradata) { 'lsp_policies_invalid' }

        it { is_expected.to compile.and_raise_error(%r{Invalid Policy name: Super secret custom policy}) }
      end
    end
  end
end
