require './ci/common'

def supervisor_version
  ENV['FLAVOR_VERSION'] || '3.1.3'
end

def supervisor_rootdir
  "#{ENV['INTEGRATIONS_DIR']}/supervisor_#{supervisor_version}_#{ENV['TRAVIS_PYTHON_VERSION']}"
end

namespace :ci do
  namespace :supervisord do |flavor|
    task :before_install => ['ci:common:before_install']

    task :install => ['ci:common:install'] do
      unless Dir.exist? File.expand_path(supervisor_rootdir)
        sh %(pip install supervisor==#{supervisor_version} --ignore-installed\
             --install-option="--prefix=#{supervisor_rootdir}")
      end
    end

    task :before_script => ['ci:common:before_script'] do
      sh %(mkdir -p $VOLATILE_DIR/supervisor)
      %w(supervisord.conf supervisord.yaml).each do |conf|
        sh %(cp $TRAVIS_BUILD_DIR/ci/resources/supervisord/#{conf}\
             $VOLATILE_DIR/supervisor/)
        sh %(sed -i -- 's/VOLATILE_DIR/#{ENV['VOLATILE_DIR'].gsub '/','\/'}/g'\
           $VOLATILE_DIR/supervisor/#{conf})
      end

      3.times do |i|
        sh %(cp $TRAVIS_BUILD_DIR/ci/resources/supervisord/program_#{i}.sh\
             $VOLATILE_DIR/supervisor/)
      end
      sh %(chmod a+x $VOLATILE_DIR/supervisor/program_*.sh)

      sh %(#{supervisor_rootdir}/bin/supervisord\
           -c $VOLATILE_DIR/supervisor/supervisord.conf)
      sleep_for 3
    end

    task :script => ['ci:common:script'] do
      Rake::Task['ci:common:run_tests'].invoke(['supervisord'])
    end

    task :before_cache => ['ci:common:before_cache']

    task :cache => ['ci:common:cache']

    task :cleanup => ['ci:common:cleanup'] do
      sh %(kill `cat $VOLATILE_DIR/supervisor/supervisord.pid`)
      sh %(rm -rf $VOLATILE_DIR/supervisor)
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
