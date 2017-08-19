require "spec_helper"

RSpec.describe Delayed::Plugins::Tracer do
  let(:tracer) { Test::Tracer.new }

  after do
    Delayed::Worker.plugins = []
    Delayed::Job.delete_all
  end

  describe "enqueue - client side" do
    describe "auto-instrumentation" do
      before do
        Delayed::Worker.plugins = [Delayed::Plugins::Tracer.build(tracer: tracer)]
        schedule_test_job
      end

      it "creates a new span" do
        expect(tracer.finished_spans).not_to be_empty
      end

      it "sets operation_name to job name" do
        expect(tracer.finished_spans.first.operation_name).to eq("TestJob")
      end

      it "sets standard OT tags" do
        tags = tracer.finished_spans.first.tags
        [
          ['component', 'Delayed::Job'],
          ['span.kind', 'client']
        ].each do |key, value|
          expect(tags[key]).to eq(value), "expected tag '#{key}' value to equal '#{value}', got '#{tags[key]}'"
        end
      end

      it "sets database specific OT tags" do
        tags = tracer.finished_spans.first.tags
        [
          ['dj.queue', 'test'],
        ].each do |key, value|
          expect(tags[key]).to eq(value), "expected tag '#{key}' value to equal '#{value}', got '#{tags[key]}'"
        end
      end
    end

    describe "active span propagation" do
      let(:root_span) { tracer.start_span("root") }

      before do
        Delayed::Worker.plugins = [Delayed::Plugins::Tracer.build(tracer: tracer, active_span: -> { root_span })]
        schedule_test_job
      end

      it "creates the new span with active span trace_id" do
        enqueue_span = tracer.finished_spans.last
        expect(enqueue_span.context.trace_id).to eq(root_span.context.trace_id)
      end

      it "creates the new span with active span as a parent" do
        enqueue_span = tracer.finished_spans.last
        expect(enqueue_span.context.parent_span_id).to eq(root_span.context.span_id)
      end
    end

    describe "span context injection" do
      before do
        Delayed::Worker.plugins = [Delayed::Plugins::Tracer.build(tracer: tracer)]
        schedule_test_job
      end

      it "injects span context of enqueue span" do
        enqueue_span = tracer.finished_spans.last

        job = Delayed::Job.last
        carrier = MultiJson.load(job.metadata)
        extracted_span_context = tracer.extract(OpenTracing::FORMAT_TEXT_MAP, carrier)

        expect(enqueue_span.context.trace_id).to eq(extracted_span_context.trace_id)
        expect(enqueue_span.context.span_id).to eq(extracted_span_context.span_id)
        expect(enqueue_span.context.parent_span_id).to eq(extracted_span_context.parent_span_id)
      end
    end
  end

  describe "perform - server side" do
    describe "auto-instrumentation" do
      before do
        @job = schedule_test_job
        Delayed::Worker.plugins = [Delayed::Plugins::Tracer.build(tracer: tracer)]
        Delayed::Worker.new.work_off
      end

      it "creates a new span" do
        expect(tracer.finished_spans).not_to be_empty
        expect(tracer.finished_spans.size).to eq(1)
      end

      it "sets operation_name to job name" do
        expect(tracer.finished_spans.first.operation_name).to eq("TestJob")
      end

      it "sets standard OT tags" do
        tags = tracer.finished_spans.first.tags
        [
          ['component', 'Delayed::Job'],
          ['span.kind', 'server']
        ].each do |key, value|
          expect(tags[key]).to eq(value), "expected tag '#{key}' value to equal '#{value}', got '#{tags[key]}'"
        end
      end

      it "sets database specific OT tags" do
        tags = tracer.finished_spans.first.tags
        [
          ['dj.id', @job.id],
          ['dj.queue', 'test'],
          ['dj.attempts', 0]
        ].each do |key, value|
          expect(tags[key]).to eq(value), "expected tag '#{key}' value to equal '#{value}', got '#{tags[key]}'"
        end
      end
    end
  end

  describe "client-server trace context propagation" do
    let(:root_span) { tracer.start_span("root") }

    before do
      Delayed::Worker.plugins = [Delayed::Plugins::Tracer.build(tracer: tracer, active_span: -> { root_span })]
      schedule_test_job
      Delayed::Worker.new.work_off
      root_span.finish
    end

    it "creates spans for each part of the chain" do
      expect(tracer.finished_spans).not_to be_empty
      expect(tracer.finished_spans.size).to eq(3)
    end

    it "all spans contains the same trace_id" do
      tracer.finished_spans.each do |span|
        expect(span.context.trace_id).to eq(root_span.context.trace_id)
      end
    end

    it "propagates parent child relationship properly" do
      client_span = tracer.finished_spans[0]
      server_span = tracer.finished_spans[1]
      expect(client_span.context.parent_span_id).to eq(root_span.context.span_id)
      expect(server_span.context.parent_span_id).to eq(client_span.context.span_id)
    end
  end

  def schedule_test_job
    Delayed::Job.enqueue(TestJob.new, queue: "test")
  end

  class TestJob
    def perform
    end
  end
end
