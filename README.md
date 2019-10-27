# UndercoverCI

Undercover code coverage warnings as a Github App.

Check out the [undercover gem](https://github.com/grodowski/undercover) while this project is under construction.

![wip](https://media1.giphy.com/media/oDXVyGCO7f4A0/giphy.gif?cid=3640f6095bec729162584275360b6922)

## Uploading coverage data

UndercoverCI only accepts LCOV-formatted coverage reports. Please use the `simplecov-lcov` gem to generate them when running your specs. Then you should be able to create a build step uploading the coverage file with `uploader.rb`.

Example:
```
ruby -e "$(curl -s https://undercover-ci.com/uploader.rb)" -- \
  --repo grodowski/undercover-ci \
  --commit $TRAVIS_COMMIT \
  --lcov coverage/lcov/undercover-ci.lcov
```
