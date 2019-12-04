# Swiftype Fork of postrank-uri

This repo contains a Swiftype-specific fork of postrank-uri gem.
There is a number of changes we have made that are not in the upstream, 
so we have to use this version for now.

## Releasing a new version

### Configure authentication for artifactory

Create `~/.gem/credentials` with 600 permission:

```sh
mkdir -p ~/.gem && touch ~/.gem/credentials && chmod 600 ~/.gem/credentials
```

Sign into artifactory and get your API token from your [user profile](https://artifactory.elstc.co/artifactory/webapp/#/profile).

Set `USERNAME` and `API_TOKEN` in the following snippet and run it:

```sh
export USERNAME=username
export API_TOKEN=supersecret
curl --silent --fail --user "${USERNAME}:${API_TOKEN}" \
  https://artifactory.elstc.co/artifactory/api/gems/swiftype-gems/api/v1/api_key.json | \
  jq -r '.rubygems_api_key | ":elastic: \(.)"' > ~/.gem/credentials
```

### Release Process

When you make a change in this repository, please use the following process for
releasing your changes into Swiftype's private gem repository:

0. Follow the [above section](#Configure-authentication-for-artifactory) to configure push access to artifactory
1. Commit all of the changes you want to release.
2. Bump up the swiftype version (the number at the very end of the `VERSION` string) in `lib/postrank-uri/version.rb`.
3. Update SWIFTYPE-CHANGELOG.md and include information on your changes.
4. Commit and push your changes to Github.
5. Run `bundle install` to make sure the gem could be installed.
6. Run `rake release` to generate a gem file and push it to artifactory
