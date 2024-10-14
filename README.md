# Argot

> **Argot** (/är′gō/)
> _noun_
> 
> A characteristic language of a particular group (as among thieves).

Argot is a simple gem for quickly and flexibly building minimal, validatable YAML schemas. Its original inspiration came from [this blog post](https://notes.burke.libbey.me/yaml-schema/) by [@burke](https://github.com/burke).

Argot aims to be:
  - Simple (i.e., non-bureuacratic)
  - Flexible
  - Easy to Understand and Extend

Argot aims to avoid:
  - Arcane syntax
  - Having many layers of abstraction between the schema you write and the document you validate

### Example Schema

```yaml
%TAG ! tag:argot.packfiles.io,2024:
---

# "version" is optional. When supplied, it must be the literal string "latest" or match the regular expression ^\d+.\d+.\d+$
# The !one tag describes a sequence of acceptable validation rules for a given key
!o version: !one
- !l "latest"
- !x '^\d+.\d+.\d+$'

# "farmer_name" is required, and its value must match the regular expression ^Farmer [a-zA-Z]+$
!r farmer_name: !x '^Farmer [a-zA-Z]+$'

# "farmer_level" must be an Integer type
!o farmer_level: !t Integer

# The !x tag can also be used to describe validations that are applied 
# to any keys in a mapping whose name matches a regular expression
!o meats:
  !x 'beef_from_.*':
    !r grade: !one
      - !l "A"
      - !l "B"
      - !l "C"
      - !l "F"

# When a parent key is marked as optional, validation rules will be applied to its children only
# when that parent key is present in the document. In this case, the absence of the required 
# pasture_uuid key will only fail validation if its parent goat_zone key is present.
!o farm:
  !o goat_zone:
    !r pasture_uuid: !x '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
    !o goats_count: !t Integer
```

## Installation

Install the gem and add to the application's Gemfile by executing:

    $ bundle add argot

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install argot

## Usage

TODO: Write usage instructions here

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/chtzvt/argot.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

Made with :heart: by [Packfiles :package:](https://packfiles.io)