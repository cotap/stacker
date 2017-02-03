require 'spec_helper'
require 'ostruct'

describe Stacker::Stack do

  let(:stack_config) do
    {
      'name' => 'StackOne',
      'parameters' => {
        'name' => 'StackOneName'
      }
    }
  end

  let(:region_options) { { stack_prefix: 'Test-' } }

  let(:region) do
    Stacker::Region.new 'us-foo-1', {}, [ stack_config ], templates_path, region_options
  end

  subject(:stack) do
    region.stacks.first
  end

  describe '#exists?' do
    it 'returns true when the client can locate the stack' do
      allow(stack).to receive(:client).and_return(Object)
      expect(stack).to be_exists
    end

    it 'returns false when the client cannot locate the stack' do
      allow(stack).to receive(:client).and_return(nil)
      expect(stack).to_not be_exists
    end
  end

  describe '#status' do
    it 'returns the stack status' do
      allow(stack).to receive(:client)
        .and_return(OpenStruct.new(stack_status: 'CREATE_COMPLETE'))

      expect(stack.status).to eq 'CREATE_COMPLETE'
    end

    it 'returns an error message when the client is nil' do
      allow(stack).to receive(:client).and_return(nil)
      expect(stack.status).to eq "Test-StackOne:\nStack with id Test-StackOne does not exist"
    end
  end

  it 'debugs' do
    puts
  end

  describe 'client delegates' do
    it 'delegates client methods to client' do
      client = double("client")
      allow(stack).to receive(:client).and_return(client)
      described_class::CLIENT_METHODS.each do |method|
        expect(client).to receive(method.to_sym)
        stack.send(method.to_sym)
      end
    end
  end

  describe '#complete?' do
    it 'returns true if complete is in the status' do
      allow(stack).to receive(:status).and_return('CREATE_COMPLETE')
      expect(stack).to be_complete
    end

    it 'returns false if complete is not in the status' do
      allow(stack).to receive(:status).and_return('CREATE_FAILED')
      expect(stack).to_not be_complete
    end
  end

  describe '#failed?' do
    it 'returns true if failed is in the status' do
      allow(stack).to receive(:status).and_return('CREATE_FAILED')
      expect(stack).to be_failed
    end

    it 'returns false if failed is not in the status' do
      allow(stack).to receive(:status).and_return('CREATE_COMPLETE')
      expect(stack).to_not be_failed
    end
  end

  describe '#in_progress?' do
    it 'returns true if in_progress is in the status' do
      allow(stack).to receive(:status).and_return('CREATE_IN_PROGRESS')
      expect(stack).to be_in_progress
    end

    it 'returns false if in_progress is not in the status' do
      allow(stack).to receive(:status).and_return('CREATE_COMPLETE')
      expect(stack).to_not be_in_progress
    end
  end

  describe '#template' do
    it 'returns a template instance' do
      expect(Stacker::Stack::Template).to receive(:new)
        .with(stack).and_call_original
      expect(stack.template).to be_a Stacker::Stack::Template
    end
  end

  describe '#parameters' do
    it 'returns a parameters instance' do
      expect(Stacker::Stack::Parameters).to receive(:new)
        .with(stack).and_call_original
      expect(stack.parameters).to be_a Stacker::Stack::Parameters
    end
  end

  describe '#capabilities' do
    it 'returns a capabilities instance' do
      expect(Stacker::Stack::Capabilities).to receive(:new)
        .with(stack).and_call_original
      expect(stack.capabilities).to be_a Stacker::Stack::Capabilities
    end
  end

  describe '#create' do
    subject(:create) do
      stack.create false # non-blocking
    end

    before do
      allow(stack).to receive(:exists?).and_return(false)
    end

    it 'creates the stack' do
      allow(stack).to receive(:parameters)
        .and_return(OpenStruct.new(missing: [], resolved: { 'name' => 'StackOneName' }))

      client = double("client")
      allow(stack).to receive(:region).and_return(OpenStruct.new(client: client))

      capabilities = OpenStruct.new(local: { 'capa': 'bilities' })
      allow(stack).to receive(:capabilities).and_return(capabilities)

      template = OpenStruct.new(local_raw: '{"template": "source"}')
      allow(stack).to receive(:template).and_return(template)

      expect(client).to receive(:create_stack).with(
        stack_name: 'Test-StackOne',
        template_body: template.local_raw,
        parameters: [{ parameter_key: 'name', parameter_value: 'StackOneName' }],
        capabilities: capabilities.local
      )

      create
    end

    it 'warns and returns when the stack exists' do
      allow(stack).to receive(:exists?).and_return(true)
      expect(Stacker.logger).to receive(:warn)
      create
    end

    it 'raises an exception when parameters are missing' do
      allow(stack).to receive(:parameters).and_return(OpenStruct.new(missing: ['Name']))
      expect { create }.to raise_error(Stacker::Stack::MissingParameters)
    end
  end

  describe '#update' do
    let(:described_change_set) do
      [
        {
          type: "Resource",
          change: {
            logical_resource_id: "MyResource",
            action: "Modify",
            replacement: "True", # Requires allow_destructive
          }
        }
      ]
    end
    let(:change_set) { { "Change": "Set" } }
    let(:client) { double("client") }
    let(:parameters) do
      OpenStruct.new(missing: [], resolved: { 'name' => 'StackOneName' })
    end

    let(:allow_destructive) { true }
    subject(:update) do
      stack.update allow_destructive: allow_destructive, blocking: false
    end

    before do
      allow(stack).to receive(:parameters)
        .and_return(parameters)

      allow(stack).to receive(:describe_change_set)
        .and_return(described_change_set)

      allow(stack).to receive(:change_set)
        .and_return(change_set)

      allow(stack).to receive(:region)
        .and_return(OpenStruct.new(client: client))
    end

    it 'updates the stack' do
      expect(client).to receive(:execute_change_set).with(
        change_set_name: change_set,
        stack_name: 'Test-StackOne'
      )

      update
    end

    context 'missing params' do
      let(:parameters) do
        OpenStruct.new(missing: ['Name'], resolved: {})
      end

      it 'raises an exception when params are missing' do
        expect { update }.to raise_error(Stacker::Stack::MissingParameters)
      end
    end

    context 'destructive changes without allowing them' do
      let(:allow_destructive) { false }

      it 'raises an exception when params are missing' do
        expect { update }.to raise_error(Stacker::Stack::StackPolicyError)
      end
    end
  end

end
