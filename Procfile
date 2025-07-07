web: bin/rails server -p ${PORT:-5000} -e $RAILS_ENV
sidekiq-runner: bundle exec sidekiq -q runner -q default --timeout 120 -c ${SIDEKIQ_CONCURRENCY:-4} -e $RAILS_ENV
