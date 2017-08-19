module Delayed::Plugins::Tracer
  class Handler
    attr_reader :tracer, :active_span

    def initialize(tracer:, active_span: nil, lifecycle:)
      @tracer = tracer
      @active_span = active_span

      lifecycle.around(:enqueue, &method(:enqueue))
      lifecycle.around(:perform, &method(:perform))
    end

    def enqueue(job, &proceed)
      tags = {
        'component' => 'Delayed::Job',
        'span.kind' => 'client',
        'dj.queue' => (job.queue || 'default')
      }
      Method::Tracer.trace(operation_name(job), tracer: tracer, child_of: active_span, tags: tags) do |span|
        inject(span, job)
        proceed.call(job)
      end
    end

    def perform(worker, job, &proceed)
      tags = {
        'component' => 'Delayed::Job',
        'span.kind' => 'server',
        'dj.id' => job.id,
        'dj.queue' => (job.queue || 'default'),
        'dj.attempts' => job.attempts
      }
      parent_span_context = extract(job)

      Method::Tracer.trace(operation_name(job), tracer: tracer, child_of: parent_span_context, tags: tags) do |span|
        proceed.call(worker, job)
      end
    end

  private

    def inject(span, job)
      carrier = {}
      tracer.inject(span.context, OpenTracing::FORMAT_TEXT_MAP, carrier)
      job.metadata = MultiJson.dump(carrier)
    end

    def extract(job)
      return unless job.metadata
      carrier = MultiJson.load(job.metadata)
      tracer.extract(OpenTracing::FORMAT_TEXT_MAP, carrier)
    rescue MultiJson::ParseError
    end

    def operation_name(job)
      YAML.load(job.handler).class.to_s rescue "UnknownJob"
    end
  end
end
