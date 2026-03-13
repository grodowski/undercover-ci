web: bin/rails server -p ${PORT:-5000} -e $RAILS_ENV
jobs: bin/jobs
sidekiq-runner: bundle exec sidekiq -q runner -q default --timeout 20 -c ${SIDEKIQ_CONCURRENCY:-4} -e $RAILS_ENV
