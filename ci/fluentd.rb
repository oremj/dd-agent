require './ci/common'

namespace :ci do
  namespace :fluentd do |flavor|
    task :before_install => ['ci:common:before_install']

    task :install => ['ci:common:install'] do
      sh %(gem install fluentd --no-ri --no-rdoc)
    end

    task :before_script => ['ci:common:before_script'] do
      pid = spawn %(fluentd -c $TRAVIS_BUILD_DIR/ci/resources/fluentd/td-agent.conf)
      Process.detach(pid)
      sh %(echo #{pid} > $VOLATILE_DIR/fluentd.pid)
      sleep_for 10
    end

    task :script => ['ci:common:script'] do
      this_provides = [
        'fluentd'
      ]
      Rake::Task['ci:common:run_tests'].invoke(this_provides)
    end

    task :before_cache => ['ci:common:before_cache']

    task :cache => ['ci:common:cache']

    task :cleanup => ['ci:common:cleanup'] do
      sh %(kill `cat $VOLATILE_DIR/fluentd.pid`)
    end

    task :execute do
      exception = nil
      begin
        %w(before_install install before_script script).each do |t|
          Rake::Task["#{flavor.scope.path}:#{t}"].invoke
        end
      rescue => e
        exception = e
        puts "Failed task: #{e.class} #{e.message}".red
      end
      if ENV['SKIP_CLEANUP']
        puts 'Skipping cleanup, disposable environments are great'.yellow
      else
        puts 'Cleaning up'
        Rake::Task["#{flavor.scope.path}:cleanup"].invoke
      end
      if ENV['TRAVIS']
        %w(before_cache cache).each do |t|
          Rake::Task["#{flavor.scope.path}:#{t}"].invoke
        end
      end
      fail exception if exception
    end
  end
end
