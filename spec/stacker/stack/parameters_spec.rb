require 'spec_helper'

describe Stacker::Stack::Parameters do

  let(:stack) { double("Stacker::Stack") }

  let(:template) do
    OpenStruct.new(
      local: {
        'Parameters' => {
          'Param1' => {
            'Type' => 'String',
            'Description' => 'First Param'
          },
          'Param2' => {
            'Type' => 'String',
            'Description'  => 'Second Param',
            'Default' => 'TemplateParam2'
          },
          'Param3' => {
            'Type' => 'String',
            'Description'  => 'Third Param',
            'Default' => 'TemplateParam3'
          }
        }
      }
    )
  end

  let(:region_params) do
    {
      'Param1' => 'RegionParam1',
      'Param2' => 'RegionParam2',
    }
  end

  let(:region) do
    OpenStruct.new(
      defaults: {
        'parameters' => region_params
      }
    )
  end

  let(:client) { double("client") }
  let(:stack_params) { { 'Param2' => 'StackParam2' } }
  let(:stack_options) do
    {
      'parameters' => stack_params
    }
  end
  let(:stack) do
    OpenStruct.new(
      template: template,
      region: region,
      options: stack_options,
      client: client
    )
  end

  subject(:parameters) do
    described_class.new stack
  end

  describe '#local' do
    it 'returns the parameters with correct merge hierarchy' do
      expect(parameters.local).to eq(
        'Param1' => 'RegionParam1', # Defined at region
        'Param2' => 'StackParam2', # Override in stack
        'Param3' => 'TemplateParam3' # Default provided by template
      )
    end
  end

  describe '#missing' do
    before do
      region_params.delete('Param1')
    end

    it 'returns params that are missing' do
      expect(parameters.missing).to eq ['Param1']
    end
  end

  describe '#remote' do
    let(:client) do
      OpenStruct.new(
        parameters: [
          OpenStruct.new(parameter_key: 'keyA', parameter_value: 'valueA'),
          OpenStruct.new(parameter_key: 'keyB', parameter_value: 'valueB')
        ]
      )
    end

    it 'maps the remote params' do
      expect(parameters.remote).to eq(
        'keyA' => 'valueA',
        'keyB' => 'valueB'
      )
    end
  end

  describe '#resolved' do
    it 'returns the resolved params' do
      expect(parameters.resolved).to eq(
        'Param1' => 'RegionParam1',
        'Param2' => 'StackParam2',
        'Param3' => 'TemplateParam3'
      )
    end
  end

  describe '#dependencies' do
    let(:stack_params) do
      {
        'Param1' => {
          'Stack' => 'OtherStack',
          'Output' => 'OtherStackOutput1'
        },
        'Param2' => {
          'Stack' => 'OtherStack',
          'Output' => 'OtherStackOutput2'
        }
      }
    end

    it 'returns the dependent params' do
      expect(parameters.dependencies).to eq [
        'OtherStack.OtherStackOutput1',
        'OtherStack.OtherStackOutput2'
      ]
    end
  end
end
