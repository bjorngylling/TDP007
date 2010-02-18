require 'rubygems'
require 'sqlite3' # gem install sqlite3-ruby

class ActiveRecord
	@@sub_classes = Hash.new
	
	class << self		
		def inherited(klass)
			@@sub_classes[klass] = {:one => Hash.new, :many => Hash.new}
		end
		
		def one(*args)
			args.each do |arg|
				@@sub_classes[self][:one][arg] = nil
			end
		end
		
		def many(*args)
			args.each do |arg|
				@@sub_classes[self][:many][arg] = nil
			end
		end
		
	end
	
	def initialize(database_connection)
		@db_con = database_connection
		@properties = @@sub_classes[self.class]
		
		if table_exists? : load_table else create_table end
	end
	
	def method_missing(method_name, *args)
		name = method_name.to_s
		if name =~ /=$/
			name = name.chop.intern
			assignment = true
		end
		
		return super unless @properties[:one].merge(@properties[:many]).has_key?(name)
		
		return @properties[:one].merge(@properties[:many])[name] unless assignment

		if @properties[:one].has_key?(name)
			@properties[:one][name] = args.to_s
		else
			@properties[:many][name] = args[0]
		end
	end
	
	###
	# Database
	
	def table_exists?
	  return true unless @db_con.get_first_row("SELECT name FROM sqlite_master WHERE name=?", self.class) == nil
	end
	
	def load_table
		puts "loading table #{self.class}..."
	end
	
	def create_table
		puts "creating table #{self.class}..."
	end
	
end

class VEvent < ActiveRecord
	one :name, :description, :dtstart, :duration, :summary, :uid
	many :category
end

class Family < ActiveRecord
	one :mother, :father
	many :children
end

# Load the database
database = SQLite3::Database.new("sem3_sqlite3.db")

# Create our object with our database-connection
a = VEvent.new(database)

f = Family.new(database)

a.description = "Lecture in TDP007"
a.name = "DSL and Parsers"
a.category = %w(IDA SU17 SU18)
