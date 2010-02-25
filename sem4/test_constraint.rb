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
		
		a.forget_value "user"
		c.user_assign(20)
		assert_equal(15, a.value)
		
		b.forget_value "user"
		a.user_assign(15)
		c.user_assign(29)
		assert_equal(14, b.value)
	end
	
	def test_multiplier
		a = Connector.new("a")
		b = Connector.new("b")
		c = Connector.new("c")
		Multiplier.new(a, b, c)
		
		a.user_assign(10)
		b.user_assign(5)
		assert_equal(50, c.value) 
		
		a.forget_value "user"
		c.user_assign(20)
		assert_equal(4, a.value)
		
		b.forget_value "user"
		a.user_assign(3)
		c.user_assign(9)
		assert_equal(3, b.value)
	end
	
	def test_celsius2fahrenheit
		c,f=fahrenheit2celsius
		
		c.user_assign 100
		assert_equal(212, f.value)
		
		c.user_assign 0
		assert_equal(32, f.value)
		
		c.forget_value "user"
		f.user_assign 100
		assert_equal(37, c.value)
	end
	
end
