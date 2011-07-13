class GlobalConfig

  DEFAULT_CONFIG = {'frequency' => 10, 'ruby' => 'ree-1.8.7-2011.03', 'timeout' => 10.minutes}

  class << self
    def ruby
      config_hash['ruby']
    end

    def frequency
      config_hash['frequency']
    end

    def timeout
      config_hash['timeout']
    end

    def config_hash
      @config_hash ||= DEFAULT_CONFIG.merge(read_settings_hash)
    end

    def read_settings_hash
      if File.exists?("#{Rails.root}/config/goldberg.yml")
        YAML::load_file("#{Rails.root}/config/goldberg.yml")[Rails.env]
      else
        {}
      end
    end
  end


end
