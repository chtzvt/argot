# frozen_string_literal: true

require_relative "lib/argot/version"

Gem::Specification.new do |spec|
  spec.name = "argot"
  spec.version = Argot::VERSION
  spec.authors = ["Charlton Trezevant"]
  spec.email = ["charlton@packfiles.io"]

  spec.summary = "Argot is a simple gem for quickly and flexibly building minimal, validatable YAML schemas."
  spec.description = "Quickly and flexibly build minimal, validatable YAML schemas."
  spec.homepage = "https://github.com/chtzvt/argot"
  spec.licenses = ["MIT"]
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/chtzvt/argot"
  spec.metadata["changelog_uri"] = "https://github.com/chtzvt/argot"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end

  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "psych", ">= 5.1"
end
