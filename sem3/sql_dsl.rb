require 'rubygems'
require 'sqlite3' # gem install sqlite3-ruby

class ActiveRecord
	attr_accessor(:attributes)
	def initialize(database_connection)
		@db_con = database_connection
		@attributes = {:one => {}, :many => {}}
	end
	
	# This is where the magic happens
	def method_missing(name, *args)
		# "one" and "many" are keywords, make sure we handle them first
		if(%(one many).include? name.to_s)
			# Insert the attributes into the right type (one or many)
			args.each do |cur_attr|
				@attributes[name][cur_attr] = ""
			end
			
			return
		end
		
		# If name has = we're trying to set something
		if(/(\w+)=/ =~ name.to_s)
			name = $1.intern # Take the name we extracted above and make it a symbol
			
			%w(one many).each do |type| # Find the attribute and set it
				@attributes[type.intern][name] = args[0] if @attributes[type.intern].has_key?(name)
			end
			
			return
		end
		
		# If we got this far we're just trying to read a attribute
		return (@attributes[:one].merge(@attributes[:many]))[name]
		
	end
end

class VEvent < ActiveRecord
	def initialize(database_connection)
		super database_connection # Let ActiveRecord handle the database
		
		one :name, :description, :dtstart, :duration, :summary, :uid
		many :category
	end	
end

# Load the database
database = SQLite3::Database.new("sem3_sqlite3.db")

# Create our object with our database-connection
a = VEvent.new(database)

a.description = "Lecture in TDP007"
a.name = "DSL and Parsers"
a.category = %w(IDA SU17 SU18)

p a.attributes
