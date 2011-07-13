class ProjectConfig
  attr_accessor :frequency, :ruby, :rake_task, :environment_variables, :timeout, :command
  attr_reader :build_completion_callbacks, :build_failure_callbacks, :build_fixed_callbacks, :build_success_callbacks

  def initialize
    @frequency = 20
    @ruby = GlobalConfig.ruby
    @rake_task = :spec
    @environment_variables = {}
    @build_completion_callbacks = []
    @build_failure_callbacks = []
    @build_success_callbacks = []
    @build_fixed_callbacks = []
    @timeout = 10.minutes
    @command = nil
  end

  def environment_string
    @environment_variables.each_pair.map { |k, v| "#{k}=#{v}" }.join(" ")
  end

  def on_build_completion(&callback_block)
    build_completion_callbacks << callback_block
  end

  def on_build_failure(&callback_block)
    build_failure_callbacks << callback_block
  end

  def on_build_fixed(&callback_block)
    build_fixed_callbacks << callback_block
  end

  def on_build_success(&callback_block)
    build_success_callbacks << callback_block
  end
end
