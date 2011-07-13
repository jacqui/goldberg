require "fileutils"

class Project < ActiveRecord::Base
  has_many :builds, :dependent => :destroy
  after_destroy :remove
  delegate :number, :status, :build_log, :timestamp, :to => :latest_build, :prefix => true
  delegate :timestamp, :status, :to => :last_complete_build, :prefix => true

  validates_presence_of :branch, :name, :url

  delegate :frequency, :ruby, :environment_string, :timeout, :to => :config

  def self.command_line_create(options)
    project_url = options.delete(:url)
    project_name = options.delete(:name)
    project_branch = options.delete(:branch)

    return false if [project_url, project_name, project_branch].compact.blank?

    Bundler.with_clean_env do
      Env['BUNDLE_GEMFILE'] = nil
      Env["RUBYOPT"] = nil # having RUBYOPT was causing problems while doing bundle install resulting in gems not being installed - aakash
      Env['RAILS_ENV'] = nil

      RVM.prepare_ruby(GlobalConfig.ruby, "goldberg")
      RVM.trust_rvmrc(Rails.root)

      go_to_rails_root = "cd #{Rails.root}"

      add_command = "#{Rails.root.join('bin', 'goldberg')} add #{project_url} #{project_name} --branch #{project_branch}"

      full_command = [RVM.use_script(GlobalConfig.ruby, "goldberg"), go_to_rails_root, add_command].compact.join(' ; ')

      Rails.logger.info "Running '#{full_command}'"
      output = `#{full_command}`
      output_lines = output.split(/\n/)
      if $?.success? && output_lines.last =~ /successfully added/
        project = Project.where(:name => project_name).first
        { :status => 'succeeded', :output => output, :project => project }
      else
        { :status => 'failed', :output => output, :project => nil }

      end
    end
  end

  def self.add(options)
    project = Project.new(:name => options[:name], :url => options[:url], :branch => options[:branch])
    if project.checkout
      project.save!
      project
    end
  end

  def remove
    FileUtils.rm_rf(path)
  end

  def checkout
    self.repository.checkout.tap{|result| remove unless result}
  rescue
    remove
    raise
  end

  def build_required?
    latest_build.nil_build? || self.build_requested?
  end

  def code_path
    path("code")
  end

  def path(extra = '')
    File.join(Paths.projects, name, extra)
  end

  def latest_build
    builds.first || Build.nil
  end

  def prepare_for_build
    gemfile = File.expand_path('Gemfile', self.code_path)
    gemfilelock = File.expand_path('Gemfile.lock', self.code_path)

    if File.exists?(gemfilelock) && !repository.versioned?('Gemfile.lock') && (File.mtime(gemfile) > File.mtime(gemfilelock) || ruby != latest_build.ruby)
      Rails.logger.info("removing Gemfile.lock as it's not versioned")
      File.delete(gemfilelock)
    end
  end

  def run_build
    clean_up_older_builds
    if self.repository.update || build_required?
      previous_build_status = last_complete_build_status
      prepare_for_build
      new_build = self.builds.create!(:number => latest_build.number + 1, :previous_build_revision => latest_build.revision, :ruby => ruby,
                                      :environment_string => environment_string).tap(&:run)
      self.build_requested = false
      Rails.logger.info "Build #{ new_build.status }"
      after_build_runner.execute(new_build, previous_build_status)
    end
    self.next_build_at = Time.now + frequency.seconds
    self.save
  end

  def clean_up_older_builds
    builds.where(:status => 'building').each { |b| b.update_attributes(:status => 'cancelled') }
  end

  def after_build_runner
    BuildPostProcessor.new(config)
  end

  def force_build
    Rails.logger.info "forcing build for #{self.name}"
    self.build_requested = true
    save
  end

  def build_command
    bundler_command = File.exists?(File.join(self.code_path, 'Gemfile')) ? "#{Bundle.install_local} && " : ""
    bundler_command << (config.command || "rake #{config.rake_task}")
  end

  def map_to_cctray_project_status
    {'passed' => 'Success', 'timeout' => 'Failure', 'failed' => 'Failure'}[last_complete_build.status] || 'Unknown'
  end

  def last_complete_build
    builds.detect { |build| !['building', 'cancelled'].include?(build.status) } || Build.nil
  end

  def repository
    @repository ||= Repository.new(code_path, url, branch)
  end

  def self.find_by_name(name)
    all.detect { |project| project.name == name }
  end

  def config
    if File.exists?(File.expand_path('goldberg_config.rb', self.code_path))
      config_code = Environment.read_file(File.expand_path('goldberg_config.rb', self.code_path))
      eval(config_code)
    else
      ProjectConfig.new
    end
  end

  def self.configure
    config = ProjectConfig.new
    yield config
    config
  end

  def self.projects_to_build
    Project.where("build_requested = 't' or next_build_at is null or next_build_at <= :next_build_at", :next_build_at => Time.now)
  end

  def activity
    {'passed' => 'Sleeping', 'timeout' => 'Sleeping', 'failed' => 'Sleeping', 'building' => 'Building'}[latest_build_status] || 'Unknown'
  end

  def github_url
    url.gsub(/^git:\/\//, 'http://').gsub(/\.git$/, '') if url.include?('//github.com')
  end
end
