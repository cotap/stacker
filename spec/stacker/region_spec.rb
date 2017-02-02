require 'spec_helper'

describe Stacker::Region do

  let(:region_name) { 'us-foo-1' }
  let(:defaults) { { default: 'value' } }
  let(:stack_prefix) { 'Test-' }
  let(:options) { { stack_prefix: stack_prefix } }

  let(:stacks) do
    [
      {
        'name' => 'StackOne',
        'parameters' => {
          'name' => 'StackOneName'
        }
      }
    ]
  end

  subject(:region) do
    described_class.new region_name, defaults, stacks, templates_path, options
  end

  its(:name) { is_expected.to eq region_name }
  its(:defaults) { is_expected.to eq defaults }
  its(:templates_path) { is_expected.to eq templates_path }
  its(:options) { is_expected.to eq options }

  it 'instantiates stack instances' do
    region.stacks.first.tap do |stack|
      expect(stack.name).to eq 'Test-StackOne'
      expect(stack.region).to eq region
      expect(stack.options).to match({
        'name' => 'Test-StackOne',
        'template_name' => 'StackOne',
        'parameters' => {
          'name' => 'StackOneName'
        }
      })
    end
  end

  describe '#client' do
    it 'provides a client for the region' do
      expect(Aws::CloudFormation::Client).to receive(:new)
        .with(region: region_name).and_call_original
      expect(region.client).to be_a Aws::CloudFormation::Client
    end
  end

  describe '#stack' do
    it 'returns a stack by name' do
      expect(region.stack('Test-StackOne')).to be_a Stacker::Stack
    end

    it 'raises an exception for undeclared stacks' do
      expect { region.stack('NotAStack') }.to raise_error Stacker::Stack::StackUndeclared
    end
  end

end
