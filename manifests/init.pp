# @summary Configure local security policy for Windows servers.
#
# This class can be used to specify `local_security_policy` resources in Hiera.  For example,
# ```yaml
# local_security_policy::policies:
#   'Audit account logon events':
#     ensure: 'present'
#     policy_setting: 'AuditAccountLogon'
#     policy_type: 'Event Audit'
#     policy_value: 'Success,Failure'
# ```
#
# @param policies Hash of `local_security_policy` resources
#
# @example
#   include local_security_policy
class local_security_policy (
  Hash $policies = {},
) {
  $policies.each |$key, $value| {
    local_security_policy { $key:
      * => $value,
    }
  }
}
