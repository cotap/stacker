require 'spec_helper'

describe Stacker::Stack::Template do

  let(:client) { double('client') }
  let(:region) do
    OpenStruct.new(
      templates_path: templates_path,
      client: client
    )
  end

  let(:template_name) { 'YAMLTest' }
  let(:stack_options) do
    { 'template_name' => template_name }
  end

  let(:stack_name) { 'Test' }
  let(:stack) do
    OpenStruct.new(
      name: stack_name,
      region: region,
      options: stack_options
    )
  end

  subject(:template) do
    described_class.new stack
  end

  describe '#exists?' do
    it 'returns true when the template file exists' do
      expect(template).to be_exists
    end

    context 'missing template file' do
      let(:template_name) { 'DoesNotExist' }
      it 'returns false' do
        expect(template).to_not be_exists
      end
    end
  end

  describe '#local_raw' do
    it 'reads the template file' do
      template_source = File.read File.join(templates_path, "#{template_name}.yml")
      expect(template.local_raw).to eq template_source
    end
  end

  describe '#local' do
    context 'yaml format' do
      it 'reads the template file' do
        template_source = YAML.load(File.read File.join(templates_path, "#{template_name}.yml"))
        expect(template.local).to eq template_source
      end
    end

    context 'json format' do
      let(:template_name) { 'JSONTest' }
      it 'reads the template file' do
        template_source = JSON.parse(File.read File.join(templates_path, "#{template_name}.json"))
        expect(template.local).to eq template_source
      end
    end

    context 'missing template' do
      let(:template_name) { 'DoesNotExist' }
      it 'raises an error' do
        expect { template.local }.to raise_error(Stacker::Stack::TemplateDoesNotExistError)
      end
    end
  end

  describe '#remote_raw' do
    it 'fetches the remote template' do
      expect(client).to receive(:get_template).with(stack_name: stack_name)
        .and_return(OpenStruct.new(template_body: 'template-body'))

      expect(template.remote_raw).to eq 'template-body'
    end
  end

  describe '#remote' do
    let(:template_name) { 'JSONTest' }
    it 'fetches the remote template' do
      template_source = File.read File.join(templates_path, "#{template_name}.json")
      expect(template).to receive(:remote_raw).and_return(template_source)

      expect(template.remote).to eq JSON.parse(template_source)
    end
  end

  describe '#write' do
    let(:template_name) { 'JSONTest' }
    it 'writes the template in JSON format to disk' do
      expect(File).to receive(:write).with(File.join(templates_path, "#{template_name}.json"), "{\n  \"foo\": \"bar\"\n}\n")
      template.write JSON.parse('{"foo": "bar"}')
    end
  end

  describe '#dump' do
    it 'writes the remote template to disk' do
      expect(template).to receive(:remote).and_return('template')
      expect(template).to receive(:write).with('template')
      template.dump
    end
  end

end
