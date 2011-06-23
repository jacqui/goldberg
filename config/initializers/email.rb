Goldberg::Application.config.action_mailer.delivery_method = :smtp

Goldberg::Application.config.action_mailer.smtp_settings = {
  :address              => "localhost",
  :authentication       => 'plain',
  :enable_starttls_auto => true
}

Goldberg::Application.config.action_mailer.default_url_options = {
  :host => "localhost"
}
