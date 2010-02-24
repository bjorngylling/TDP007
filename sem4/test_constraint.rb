require "test/unit"
require "constraint_networks.rb"




class TestCN < Test::Unit::TestCase
	def test_adder
		a = Connector.new("a")
		b = Connector.new("b")
		c = Connector.new("c")
		Adder.new(a, b, c)
		a.user_assign(10)
		b.user_assign(5)
		
		assert_equal(15, c.value) 
		
		#puts "c = "+c.value.to_s
		
		a.forget_value "user"
		c.user_assign(20)
		
		assert_equal(15, a.value)
		
		b.forget_value "user"
		c.user_assign(29)
		
		p b.value
		#assert_equal(14, b.value)
	end
	
	
	
end
