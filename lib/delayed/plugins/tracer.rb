require 'opentracing'
require 'multi_json'
require "active_record"
require "delayed_job"
require "delayed_job_active_record"
require 'method-tracer'

require 'delayed/plugins/tracer/handler'

module Delayed
  module Plugins
    module Tracer
      class << self
        def build(tracer: OpenTracing.global_tracer, active_span: nil)
          Class.new(Delayed::Plugin) do
            callbacks do |lifecycle|
              Handler.new(tracer: tracer,
                          active_span: active_span,
                          lifecycle: lifecycle)
            end
          end
        end
      end
    end
  end
end
