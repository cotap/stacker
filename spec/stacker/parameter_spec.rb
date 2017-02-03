require 'spec_helper'

class Stacker::Resolvers::EchoResolver < Stacker::Resolvers::Resolver
  def resolve
    ref
  end
end

describe Stacker::Stack::Parameter do

  let(:region) { double('Stacker::Region') }

  let(:simple_value) { 'SimpleValue' }
  let(:stack_output_value) do
    {
      'Stack' => 'SomeStack',
      'Output' => 'SomeStackOutput'
    }
  end
  let(:file_value) do
    {
      'File' => 'secrets.txt'
    }
  end

  describe '#value' do
    it 'returns the value' do
      parameter = described_class.new simple_value, region
      expect(parameter.value).to eq simple_value
    end

    it 'returns an array of parameters for array values' do
      values = ['one', 'two']
      parameter = described_class.new values, region
      expect(parameter.value).to eq values.map { |v| described_class.new v, region }
    end
  end

  describe '#dependency?' do
    it 'returns true for hash values' do
      parameter = described_class.new stack_output_value, region
      expect(parameter).to be_dependency
    end

    it 'returns false for non-hash values' do
      parameter = described_class.new simple_value, region
      expect(parameter).to_not be_dependency
    end
  end

  describe '#dependencies' do
    it 'returns a keyed value for dependencies' do
      parameter = described_class.new stack_output_value, region
      expect(parameter.dependencies).to eq(
        ["#{stack_output_value['Stack']}.#{stack_output_value['Output']}"]
      )
    end

    context 'dependency array' do
      it 'returns an array of keyed values for dependencies' do
        parameter = described_class.new [stack_output_value, file_value], region
        expect(parameter.dependencies).to eq(
          [
            "#{stack_output_value['Stack']}.#{stack_output_value['Output']}",
            "#{file_value.first.last}"
          ]
        )
      end
    end

    context 'simple value' do
      it 'returns empty set' do
        parameter = described_class.new simple_value, region
        expect(parameter.dependencies).to eq []
      end
    end
  end

  describe '#resolved' do
    let(:echo_value) do
      {
        'Echo' => 'Hola mundo'
      }
    end

    it 'returns the resolved value' do
      parameter = described_class.new echo_value, region
      expect(parameter.resolved).to eq 'Hola mundo'
    end

    context 'with invalid resolver' do
      let(:invalid_resolver_value) do
        {
          'NotAResolver' => 'whoa'
        }
      end

      it 'raises an error' do
        parameter = described_class.new invalid_resolver_value, region
        expect { parameter.resolved }.to raise_error(Stacker::Stack::ParameterResolutionError)
      end
    end

    context 'array value' do
      let(:echo_values) do
        [
          { 'Echo' => 'Hola mundo' },
          { 'Echo' => 'Hello world' }
        ]
      end
      it 'returns the resolved values' do
        parameter = described_class.new echo_values, region
        expect(parameter.resolved).to eq 'Hola mundo,Hello world'
      end
    end

    context 'simple value' do
      it 'returns the value' do
        parameter = described_class.new 'Hello', region
        expect(parameter.resolved).to eq 'Hello'
      end
    end
  end

end
