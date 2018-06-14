require 'erb'
require 'dsc_utils'
require 'securerandom'
test_name 'FM-2625 - C68511 - Apply DSC Resource Manifest via "puppet apply"'

installed_path = get_fake_reboot_resource_install_path(usage = :manifest)

confine(:to, :platform => 'windows')

# ERB Manifest
test_dir_path = SecureRandom.uuid
fake_name = SecureRandom.uuid
test_file_contents = SecureRandom.uuid

dsc_manifest = <<-MANIFEST
file { 'C:/#{ test_dir_path }' :
   ensure => 'directory'
}
->
dsc { '#{fake_name}':
  dsc_resource_name => 'puppetfakeresource',
  dsc_resource_module => '#{installed_path}/1.0',
  dsc_resource_properties => {
    ensure          => 'present',
    importantstuff  => '#{test_file_contents}',
    destinationpath => '#{"C:\\" + test_dir_path + "\\" + fake_name}',
  },
}
MANIFEST

# Teardown
teardown do
  step 'Remove Test Artifacts'
  on(agents, "rm -rf /cygdrive/c/#{test_dir_path}")
  agents.each do |agent|
    uninstall_fake_reboot_resource(agent)
  end
end

# Tests
agents.each do |agent|
  step 'Copy Test Type Wrappers'
  install_fake_reboot_resource(agent)

  step 'Apply Manifest'
  on(agent, puppet('apply'), :stdin => dsc_manifest, :acceptable_exit_codes => [0,2]) do |result|
    assert_no_match(/Error:/, result.stderr, 'Unexpected error was detected!')
    assert_match(/Stage\[main\]\/Main\/Dsc\[#{fake_name}\]\/ensure\: created/, result.stdout, 'DSC Resource missing!')
  end

  step 'Verify Results'
  # PuppetFakeResource always overwrites file at this path
  on(agent, "cat /cygdrive/c/#{test_dir_path}/#{fake_name}", :acceptable_exit_codes => [0]) do |result|
    assert_match(/#{test_file_contents}/, result.stdout, 'PuppetFakeResource File contents incorrect!')
  end
end
