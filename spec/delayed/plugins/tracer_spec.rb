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
        expect(tracer).to have_spans
      end

      it "sets operation_name to job name" do
        expect(tracer).to have_span("TestJob")
      end

      it "sets standard OT tags" do
        [
          ['component', 'Delayed::Job'],
          ['span.kind', 'client']
        ].each do |key, value|
          expect(tracer).to have_span.with_tag(key, value)
        end
      end

      it "sets database specific OT tags" do
        [
          ['dj.queue', 'test'],
        ].each do |key, value|
          expect(tracer).to have_span.with_tag(key, value)
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
        expect(tracer).to have_traces(1)
        expect(tracer).to have_spans(2)
      end

      it "creates the new span with active span as a parent" do
        expect(tracer).to have_span.with_parent(root_span)
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

        expect(enqueue_span.context).to eq(extracted_span_context)
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
        expect(tracer).to have_spans(1)
      end

      it "sets operation_name to job name" do
        expect(tracer).to have_span("TestJob")
      end

      it "sets standard OT tags" do
        [
          ['component', 'Delayed::Job'],
          ['span.kind', 'server']
        ].each do |key, value|
          expect(tracer).to have_span.with_tag(key, value)
        end
      end

      it "sets database specific OT tags" do
        [
          ['dj.id', @job.id],
          ['dj.queue', 'test'],
          ['dj.attempts', 0]
        ].each do |key, value|
          expect(tracer).to have_span.with_tag(key, value)
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
      expect(tracer).to have_spans(3)
    end

    it "all spans contains the same trace_id" do
      expect(tracer).to have_traces(1)
    end

    it "propagates parent child relationship properly" do
      client_span = tracer.finished_spans[0]
      server_span = tracer.finished_spans[1]
      expect(client_span).to be_child_of(root_span)
      expect(server_span).to be_child_of(client_span)
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
