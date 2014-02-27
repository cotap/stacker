stacker
=======

Easily assemble CloudFormation stacks with interdependencies.

## Usage

```sh
$ stacker -h
Commands:
  stacker diff [STACK_NAME]    # Show outstanding stack differences
  stacker dump [STACK_NAME]    # Download stack template
  stacker fmt [STACK_NAME]     # Re-format template JSON
  stacker help [COMMAND]       # Describe available commands or one specific command
  stacker init [PATH]          # Create stacker project directories
  stacker list                 # List stacks
  stacker show STACK_NAME      # Show details of a stack
  stacker status [STACK_NAME]  # Show stack status
  stacker update [STACK_NAME]  # Create or update stack

Options:
  [--path=project path]        # Default: STACKER_PATH or './'
  [--region=AWS region name]   # Default: STACKER_REGION or 'us-east-1'
```

## Examples

### Project Structure

```
acme-cloudformation
|-- regions
|    |-- us-east-1.yml
|    `-- us-west-1.yml
`-- templates
     |-- API.json
     |-- Database.json
     |-- PrivateSubnets.json
     |-- PublicSubnets.json
     `-- VPC.json
```

### Region File

```yaml
---
defaults:
  parameters:
    AmiImageId: 'ami-1234abcd'
    CidrBlock: '10.0'
    VPCId:
      Stack: VPC
      Output: VPCId # depend on an output from another stack

stacks:
  - name: VPC

  - name: PublicSubnets
    parameters:
      InternetGateway:
        Stack: VPC
        Output: InternetGateway

  - name: PrivateSubnets

  - name: API
    capabilities: 'CAPABILITY_IAM' # give permission to create IAM resources
    parameters:
      ChefRunList: 'role[api]'

  - name: DBMaster
    parameters:
      ChefRunList: 'role[db-master]'
      InstanceImageId: 'ami-d3adb33f'
      SubnetId:
        Stack: PublicSubnets
        Output: SubnetIdAZ1
    template_name: Database # use template with a different name

  - name: DBSlave
    parameters:
      ChefRunList: 'role[db-slave]'
    template_name: Database

```

## Authors

Martin Cozzi (<martin@cotap.com>) and Evan Owen (<evan@cotap.com>)

## License

(The MIT License)

© 2013 Cotap, Inc.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the “Software”), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
