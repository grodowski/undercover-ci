web: bin/rails server -p ${PORT:-5000} -e $RAILS_ENV
sidekiq: bundle exec sidekiq -t 25 -c 8 -e $RAILS_ENV
