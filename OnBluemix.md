## References: ##
- [Rails+Sidekiq Sample for CloudFoundry](https://docs.cloudfoundry.org/buildpacks/ruby/ruby-tips.html#rake)
- [Current CloudFoundry Buildpack for RAILS 5](https://docs.cloudfoundry.org/buildpacks/ruby/index.html)
- [Buildpack location](https://github.com/cloudfoundry/ruby-buildpack)
- [Jeff Sloyer - Rails on Bluemix]( https://www.ibm.com/blogs/bluemix/2015/03/tips-migrating-ruby-rails-applications-bluemix/)
- [Nic Williams - Sidekiq on CloudFoundry](http://www.starkandwayne.com/blog/run-sidekiq-on-cloud-foundry/)


## Buildpack level ##
the default Ruby buildpack supports
- ruby <=2.4.1
- bundler

current ruby installs are >=2.4.2 and bundler >= 1.15.4, so need a compatible buildpack configured in the manifests -
```
  buildpack: https://github.com/cloudfoundry/ruby-buildpack.git
```

## worker-manifest.yml ##
- [Health monitor override](https://docs.cloudfoundry.org/devguide/deploy-apps/manifest.html)

worker manifest updates as app does not need/provide external endpoint:
```
  health-check-type: process
```

## web-manifest.yml ##
web manifest update to specify database action
```
  command: bundle exec rake db:setup && bundle exec rails s -p $PORT
```

## Gemfile ##

match dev version of Ruby to production - specify in Gemfile; include redis, sidekiq and cf tools
```
ruby '~> 2.4.2'
...
gem 'uuidtools'

gem 'mysql2'
gem 'sidekiq'
gem 'sinatra', require: false
gem 'redis-namespace'
gem 'cf-autoconfig', '~> 0.2.1'
gem 'rails_12factor', group: :production
```

## .cfignore ##
```
/vendor/*
/db/*.sqlite3
/tmp
/log/*.log
```

## config/initializers/redis.rb ##
provide mechanism for build process to locate the Redis service binding
```
if ENV['VCAP_SERVICES']
  $vcap_services ||= JSON.parse(ENV['VCAP_SERVICES'])
  redis_service_name = $vcap_services.keys.find { |svc| svc =~ /redis/i }
  redis_service = $vcap_services[redis_service_name].first
  $redis_config = {
    host: redis_service['credentials']['hostname'],
    port: redis_service['credentials']['port'],
    password: redis_service['credentials']['password']
  }
else
  $redis_config = {
    host: '127.0.0.1',
    port: 6379
  }
end
$redis = Redis.new($redis_config)
```

## config/initializers/sidekiq.rb ##
enable Sidekiq to use established Redis configuration
```
if $redis_config[:password]
  redis_url = "redis://:#{$redis_config[:password]}@#{$redis_config[:host]}:#{$redis_config[:port]}/0"
else
  redis_url = "redis://#{$redis_config[:host]}:#{$redis_config[:port]}/0"
end
Sidekiq.redis = { url: redis_url, namespace: 'sidekiq' }
```
## Deployment ##
the web manifest run the `db:setup` command - this will be rejected in production by default - set cf envvar to override:
```
cf set-env ${WEB-APP} DISABLE_DATABASE_ENVIRONMENT_CHECK 1
cf push -f web-manifest.yml
cf push -f worker-manifest.yml
```
