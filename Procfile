web: bin/rails server -p ${PORT:-5000} -e $RAILS_ENV
sidekiq-runner: bundle exec sidekiq -q runner -t 25 -c ${SIDEKIQ_CONCURRENCY:-4} -e $RAILS_ENV
sidekiq-default: bundle exec sidekiq -q default -t 25 -c ${SIDEKIQ_CONCURRENCY:-4} -e $RAILS_ENV