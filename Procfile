web: bin/rails server -p ${PORT:-5000} -e $RAILS_ENV
sidekiq-runner: bundle exec sidekiq -q runner,1 -q default,5 -t 25 -c ${SIDEKIQ_CONCURRENCY:-4} -e $RAILS_ENV
