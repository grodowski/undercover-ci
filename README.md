# UndercoverCI

Undercover code coverage warnings as a Github App.

Check out the [undercover gem](https://github.com/grodowski/undercover) while this project is under construction.

![wip](https://media1.giphy.com/media/oDXVyGCO7f4A0/giphy.gif?cid=3640f6095bec729162584275360b6922)

## Uploading coverage data

UndercoverCI only accepts LCOV-formatted coverage reports. Please use the `simplecov-lcov` gem to generate them when running your specs. Then you should be able to create a build step uploading the coverage file with `curl`.

⚠️ This method is still a proof of concept and should not be used for real applications. ⚠️

```
coverage_base64=$(ruby -r base64 -e "print Base64.strict_encode64(File.read(\"coverage/lcov/undercover-ci.lcov\"))")
curl -iX POST -H "Content-Type: application/json" \
-d "{\"repo\": \"grodowski/undercover-ci\", \"sha\": \"$TRAVIS_COMMIT\", \"lcov_base64\": \"$coverage_base64\"}" \
https://undercover-ci.com/v1/coverage
```
