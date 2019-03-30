# Undercover CI

Undercover code coverage warnings as a Github App.

Check out the [undercover gem](https://github.com/grodowski/undercover) while this project is under construction.

![wip](https://media1.giphy.com/media/oDXVyGCO7f4A0/giphy.gif?cid=3640f6095bec729162584275360b6922)

## Uploading coverage data

The Undercover CI only accepts LCOV-formatted coverage reports. Please use the `simplecov-lcov` gem to generate them when running your specs. Then you should be able to upload coverage by running

⚠️ This method is still a proof of concept and should not be used for real applications. ⚠️

```
curl -X POST -H "Content-Type: application/json" \
-d "{\"repo\": \"grodowski/undercover-ci\", \"sha\": \"3eb49a677d75852404c898c4ecaa9b6efd335f8a\", \"lcov_base64\": \"$(cat coverage/lcov/undercover-ci.lcov | base64)\"}" \
localhost:3000/v1/coverage
```
