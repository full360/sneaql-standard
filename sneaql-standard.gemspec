Gem::Specification.new do |s|
  s.name        = 'sneaql-standard'
  s.version     = '0.0.1'
  s.date        = '2017-01-18'
  s.summary     = "standard sneaql deployment"
  s.description = "provides a cli and runtime environment for sneaql"
  s.authors     = ["jeremy winters"]
  s.email       = 'jeremy.winters@full360.com'
  s.files       = ["lib/sneaql_standard.rb"]
  
  Dir.glob('lib/sneaql_standard_lib/*.rb').each {|f| s.files << f}
  
  s.executables << 'sneaql'
  
  s.homepage    = 'https://www.full360.com'
  s.license     = 'MIT'
  s.platform = 'java'
  
  s.add_runtime_dependency 'sneaql', '~>0.0.4'
  s.add_development_dependency 'minitest', '~>5.9'
  s.add_runtime_dependency "aws-sdk", '~>2.6'
  s.add_runtime_dependency "dotenv", '~>2.1'
  s.add_runtime_dependency "thor", '~>0.19'
  
  s.required_ruby_version = '>=2.0' 
end