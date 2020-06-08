web: bin/rails server -p ${PORT:-5000} -e $RAILS_ENV
sidekiq: bundle exec sidekiq -t 25 -c 10 -e $RAILS_ENV
