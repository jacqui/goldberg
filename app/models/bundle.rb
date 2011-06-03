module Bundle
  class << self
    def check_and_install
      'bundle check --no-color || bundle install --no-color'
    end
    def install_local
      'bundle install --local'
    end
  end
end
