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

