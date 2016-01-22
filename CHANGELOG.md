# 1.0.0

## Breaking Changes
- GET calls now make a lean query. If you need access to mongoose defaults, virtuals, etc. use `{fat: true}` as an option when defining the Resource.

# 0.19.0

## Features
- add $skip query
- add $sort query
- add $addResourceCount query

# 0.15.0

## Features
- put requests trigger mongoose document middleware (save hooks, validation, etc.)

# 0.14.0

## Bugfixes
- POST of a non-array resource was not responding with the post-mongoose-save model

# 0.13.0

## Breaking changes
- remove support for aggregate schemas

## Bugfixes
- use mongoose defaults when generating resource

# 0.12.1

## Bug Fixes
- add mongoose as a dependency (not just a dev dependency)

# 0.12.0

## Features
- $in queries (e.g /products?name=apple&name=orange)

## Breaking Changes
- options.defaultQuery => options.find, and is now a function
- options.defaultLimit => options.limit
