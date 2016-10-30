require 'open3'
require 'rspec/expectations'

include RSpec::Matchers

def cmd(args)
  puts "stacker #{args}"
  Open3.capture2e("yes|stacker #{args}")[0]
end

Dir.chdir './tests'

`rm -r ./cfn/*`

cmd 'init cfn'
expect(Dir['cfn']).to match(['regions', 'templates'])

Dir.chdir 'cfn'

# Undeclared stack
expect(cmd 'status NoSuchStack').to match(
  "Stack with id NoSuchStack is not declared"
)

# Uncreated stack, no template
`cp ../files/us-east-1.yml ./regions/`

expect(cmd 'status Test-VPC').to match "Stack with id Test-VPC does not exist\n"
expect(cmd 'update Test-VPC').to match "No template found with name 'VPC'"

# Create stacks from JSON and YAML templates
`cp ../files/VPC.json ./templates/`
`cp ../files/SecurityGroup.yml ./templates/`

expect(cmd 'update Test-VPC').to match 'Stack Test-VPC created'
expect(cmd 'update Test-SecurityGroup').to match 'Stack Test-SecurityGroup created'

# Environments
`cp -r ../files/environments .`

expect(cmd 'status').to match 'Stack with id Test-Dev-VPC does not exist'

# Environments with configured stack name prefix
`cp ../files/env_config.yml ./environments/config.yml`

expect(cmd 'status').to match 'Stack with id Dev-Prefix-Test-Dev-VPC does not exist'
