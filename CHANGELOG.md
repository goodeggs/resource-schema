# 0.12.1

## Bug Fixes
- add mongoose as a dependency (not just a dev dependency)

# 0.12.0

## Features
- $in queries (e.g /products?name=apple&name=orange)

## Breaking Changes
- options.defaultQuery => options.find, and is now a function
- options.defaultLimit => options.limit
