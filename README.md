[![Build Status](https://travis-ci.org/iaintshine/ruby-delayed-plugins-tracer.svg?branch=master)](https://travis-ci.org/iaintshine/ruby-delayed-plugins-tracer)

# Delayed::Plugins::Tracer

OpenTracing auto-instrumentation for `Delayed::Job`.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'delayed-plugins-tracer'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install delayed-plugins-tracer

Run: 

    $ rails g delayed_job:install_tracer
    
This will generate a migration that will add a column for span context propagation.

Run the migration:

    $ rake db:migrate

Now it's time to initialize the plugin in `config/initializers/delayed_job.rb`, or other file where you normally initialize DelayedJob.
To create a new instance of the tracing plugin you need to specify at least a tracer instance and optionally an active span provider - a proc which returns a current active span. The gem plays nicely with [spanmanager](https://github.com/iaintshine/ruby-spanmanager).

```ruby
require "delayed/plugins/tracer"

Delayed::Worker.plugins << Delayed::Plugins::Tracer.build(tracer: OpenTracing.global_tracer,
                                                          active_span: -> { OpenTracing.global_tracer.active_span })
```

You are all set.


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/iaintshine/ruby-delayed-plugins-tracer. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.
