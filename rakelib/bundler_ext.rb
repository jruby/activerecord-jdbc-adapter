module Bundler
  class GemHelper
    def guard_already_tagged
      # parent project performs the tag
    end
    def tag_version
      Bundler.ui.confirm "Parent project tagged #{version_tag}"
      yield if block_given?
    end
  end
end
