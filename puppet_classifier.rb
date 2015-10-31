#!/opt/puppetlabs/puppet/bin/ruby

require 'puppetclassify'
require 'optparse'
require 'facter'
require 'mongo'
require 'puppet'

Mongo::Logger.logger.level = Logger::WARN

Puppet.initialize_settings

# URL of classifier as well as certificates and private key for auth
auth_info = {
  "ca_certificate_path" => Puppet.settings[:localcacert],
  "certificate_path"    => Puppet.settings[:hostcert],
  "private_key_path"    => Puppet.settings[:hostprivkey]
}

options = {}
optparse = OptionParser.new do |opts|
  opts.banner = "Usage: opts.rb [options]"

  opts.on("-i", "--import", "import classifications from mongoDB") do |i|
    options[:import] = i
  end

  opts.on("-e", "--export", "export classifications to mongoDB") do |e|
    options[:export] = e
  end

  opts.on("-f", "--file FILENAME", "export peconsole classifications to FILENAME (provide full path and filename -> /tmp/classifications.json for example)") do |f|
    options[:file] = f
  end

  opts.on("-d", "--display DISPLAY", [:puppet, :mongo, :difference], "Select which repository to display classifications (puppet, mongo, difference)") do |d|
    options[:display] = d
  end

  opts.on("-u", "--update-classes", "Update/Sync classes") do |u|
    options[:update_classes] = u
  end

  opts.on_tail("-h", "--help", "Show this message") do
    puts opts
    exit
  end
end

# check for InvalidOption exception and display help
begin
  optparse.parse!
  rescue OptionParser::InvalidOption, OptionParser::MissingArgument
  puts $!.to_s
  puts optparse
  exit
end

# check if options is empty
if ( options.empty? )
  puts optparse
  exit
end

case Facter.value(:virtual)
  when "virtualbox"
    classifier_url = 'https://puppetmaster:4433/classifier-api'
    client = Mongo::Client.new([ 'mongodb.kristianreese.com:27017' ], :database => 'classifyPeVagrant', :replica_set => 'reese', :user => 'pe-mongodb', :password => 'password')
  when "vmware"
    classifier_url = 'https://peconsole.kristianreese.com:4433/classifier-api'
    client = Mongo::Client.new([ 'mongodb.kristianreese.com:27017' ], :database => 'classifyPePuppet', :replica_set => 'reese', :user => 'pe-mongodb', :password => 'password')
end

classifications = client['classifications']
puppetclassify = PuppetClassify.new(classifier_url, auth_info)

if options[:import]
  documents = classifications.find.projection(:_id => 0)
  puppetclassify.import_hierarchy.import(documents.to_a)
end

if options[:export]
  # Delete the following Environment Groups from vagrant Puppet 3.8.x
  # Note: Agent-specified must be deleted first since it's a child of Production environment by default
  delgroup = [ 'Agent-specified environment', 'Production environment' ]

  delgroup.each do |name|
    gid = puppetclassify.groups.get_group_id(name)
    if !gid.nil?
      puppetclassify.groups.delete_group(gid)
      puts "Deleted #{name}"
    end
  end

  puts 'updating class definitions to ensure recently added modules (if any) are included in the export'
  puppetclassify.update_classes.update

  puppetclassify.groups.get_groups.to_a.each do |document|
    #replace_one: replace existing document or upsert if non-existent
    classifications.find(:id => "#{document['id']}").replace_one(document,:upsert=>true)
  end
end

if options[:file]
  #Capture all classifications from puppet; perhaps provide future option to chose from puppet or mongo as in the display option
  File.open(options[:file], "w") do |f|
    f.puts JSON.pretty_generate(puppetclassify.groups.get_groups.to_a)
  end

  #Future Feature: Import from file. Syntax would be:
  #puppetclassify.import_hierarchy.import(JSON.parse(File.read(options[:file])))
end

if options[:display] == :puppet
  puts JSON.pretty_generate(puppetclassify.groups.get_groups.to_a)
end

if options[:display] == :mongo
  documents = classifications.find.projection(:_id => 0)
  puts JSON.pretty_generate(documents.to_a)
end

if options[:update_classes]
  puts 'updating/syncing class definitions'
  puppetclassify.update_classes.update
end

if options[:display] == :difference
  #Get all documents from MongoDB EXCEPT _id field and compare against peconsole
  classifications.find.projection(:_id => 0).each do |document|
    unless puppetclassify.groups.get_group_id("#{document['name']}")
      puts "#{document['name']} exists in MongoDB but not in peconsole"
    end
  end

  #Get all classifications from peconsole and compare against MongoDB
  puppetclassify.groups.get_groups.to_a.each do |classification|
    if classifications.find(:name => "#{classification['name']}").count() == 0.0
      puts "#{classification['name']} is currently classified in puppet and NOT stored in MongoDB"
    end
  end
end
