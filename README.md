stacker
=======

Easily assemble CloudFormation stacks.

## Usage

```sh
$ stacker -h
Commands:
  stacker diff [STACK_NAME]   # show outstanding stack differences
  stacker dump [STACK_NAME]   # download stack template
  stacker fmt [STACK_NAME]    # re-format template
  stacker help [COMMAND]      # Describe available commands or one specific command
  stacker list                # list stacks
  stacker show STACK_NAME     # show details of a stack
  stacker status [STACK_NAME] # show stack status
  stacker update [STACK_NAME] # create or update stack

Options:
  [--path=project path]       # Default: STACKER_PATH or './'
  [--region=AWS region name]  # Default: STACKER_REGION or 'us-east-1'
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
