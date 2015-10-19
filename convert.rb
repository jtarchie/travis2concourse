require 'yaml'
require 'open-uri'

manifest_uri  = ARGV[0]
manifest      = YAML.load(open(manifest_uri).read)
paths         = manifest_uri.split('/')
github_url    = "https://github.com/#{paths[1..2].join('/')}"
github_branch = paths[3] || 'master'

pipeline = {}
pipeline['resources'] = [
  {
    'name'   => 'repo',
    'type'   => 'git',
    'source' => { "uri" => github_url, "branch" => github_branch }
  }
]

def docker_image(ruby_version)
  case ruby_version
  when /^jruby-.*/
    version = ruby_version.match(/jruby-(.*)/)[1]
    "jruby##{version}"
  when /^\d+\.\d+(\.\d+)?/
    "ruby##{ruby_version}"
  end
end

def supported?(ruby_version)
  !docker_image(ruby_version).nil?
end

def run_command(manifest)
  "cd repo && bundle install && #{manifest['script'] || 'rake'}"
end

case manifest['language']
when 'ruby'
  pipeline['jobs'] =
    {
      'name' => 'Ruby',
      'plan' => [
        { 'get' => 'repo' },
      ] + manifest['rvm'].collect do |ruby_version|
        if supported?(ruby_version)
          {
            'task' => "With version #{ruby_version}",
            'config' => {
              'platform' => 'linux',
              'image' => "docker:///#{docker_image ruby_version}",
              'inputs' => [{'name' => 'repo'}],
              'run' => {
                'path' => 'bash',
                'args' => [
                  '-c',
                  run_command(manifest)
                ]
              },
              'privileged' => manifest['sudo'] == 'true'
            }
          }
        end
      end.compact
  }
end

puts pipeline.to_yaml
