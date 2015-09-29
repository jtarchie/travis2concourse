require 'yaml'
require 'uri/ssh_git'

filename = ARGV[0]
manifest = YAML.load_file(filename)
base_dir = File.expand_path(File.dirname(filename))


pipeline = {}
pipeline['resources'] = [
  {
    name: 'repo',
    type: 'git',
    source: { uri: Dir.chdir(base_dir) { URI::SshGit.parse(`git remote -v | grep origin | grep fetch`.split(/\s+/)[1]).to_s } }
  }
]

case manifest['language']
when 'ruby'
  pipeline['jobs'] =
    {
      'name' => 'Ruby',
      'plan' => [
        { 'get' => 'repo' },
      ] + manifest['rvm'].collect do |ruby_version|
        {
          'task' => "With version #{ruby_version}",
          'config' => {
            'platform' => 'linux',
            'image' => "docker:///ruby##{ruby_version}",
            'inputs' => [{'name' => 'repo'}],
            'run' => {
              'path' => 'bash',
              'args' => [
                '-c',
                "cd repo && bundle install && #{manifest['script'] || 'rake'}"
              ]
            }
          }
        }
      end
  }
end

puts pipeline.to_yaml
