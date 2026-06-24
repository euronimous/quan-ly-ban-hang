if ENV['ES_HOST'].present?
  Chewy.settings = { host: ENV['ES_HOST'] }
end
