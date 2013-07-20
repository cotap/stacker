sandwich
========

Sandwich helps you put together your CloudFormation stacks.


Problematic
-----------
Dependencies between CloudFormation's stacks have to be managed manually, either by scripting, or copy pasting Stacks Outputs in between stacks creation.
Sandwich allows you to manage stack's dependencies through a YAML configuration file.

## How does it work?
To run sandwich, specify
1. the path to your config file 
2. the path to your root template folder

       ruby sandwich.rb --config=examples/configs/prod.yml --templates=examples/templates
       
## How do templates work?
Take a look at [examples/prod.yml](https://github.com/CoTap/sandwich/blob/master/examples/configs/prod.yml)

Under "stacks" list all your stacks
       
       - name: VPCProd
       - name: PublicSubnetsProd
       
The name will be the name of your Stack on CloudFormation
Each stack has a template, and a list of parameters
       
       stacks:
         - name: VPCProd
           template: vpc.json
           parameters: []
         - name: PublicSubnetsProd
           template: public-subnets.json
           parameters: []
           
The parameters there are the same as the parameters referenced inside of the JSON CloudFormation template. To give them a value there are 2 options:

1. Pass a string value
2. Reference an output from another stack

For example, we can specify a KeyName as a string, and a VpcId to attach the Subnet to:

       stacks:
         - name: VPCProd
           template: vpc.json
           parameters: []
         - name: PublicSubnetsProd
           template: public-subnets.json
           parameters:
           - param_name: KeyName
             value: production_ec2_key
           - param_name: VpcId
             value:
               stack: VPCProd
               output: VpcId

## What an output looks like.

       $ ruby sandwich.rb --config=examples/configs/prod.yml --templates=examples/templates
       D, [2013-07-19T17:45:24.269205 #3299] DEBUG -- : "Initializing Stack: VPCProd"
       I, [2013-07-19T17:45:25.176702 #3299]  INFO -- : "Using existing Stack: {VPCProd} "
       I, [2013-07-19T17:45:25.604607 #3299]  INFO -- : "VPCProd Status => CREATE_COMPLETE"
       I, [2013-07-19T17:45:26.013125 #3299]  INFO -- : "Getting current outputs for VPCProd"
       I, [2013-07-19T17:45:26.364970 #3299]  INFO -- : "VPCProd Outputs => {\"VpcId\"=>\"vpc-a3658bcd\", \"InternetGateway\"=>\"igw-9d658bf3\"}"
       I, [2013-07-19T17:45:26.739197 #3299]  INFO -- : "VPCProd Outputs => {\"VpcId\"=>\"vpc-a3658bcd\", \"InternetGateway\"=>\"igw-9d658bf3\"}"
       D, [2013-07-19T17:45:26.739309 #3299] DEBUG -- : "Initializing Stack: PublicSubnetsProd"
       I, [2013-07-19T17:45:27.227491 #3299]  INFO -- : "Using existing Stack: {PublicSubnetsProd} "
       I, [2013-07-19T17:45:27.628653 #3299]  INFO -- : "PublicSubnetsProd Status => CREATE_COMPLETE"

## License and Author

- Author:: Martin Cozzi (<martin@cotap.com>)

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
