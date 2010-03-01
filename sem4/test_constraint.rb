require "test/unit"
require "constraint-parser.rb"

class TestCN < Test::Unit::TestCase
	def atest_adder
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
	
	def atest_multiplier
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
	
	def atest_celsius2fahrenheit
		c, f = celsius2fahrenheit
		
		c.user_assign 100
		assert_equal(212, f.value)
		
		c.user_assign 0
		assert_equal(32, f.value)
		
		c.forget_value "user"
		f.user_assign 0
		assert_equal(-18, c.value)
	end
	
	def test_constraintparser_simple
		cp = ConstraintParser.new
		c,f = cp.parse "9+c=f/5"
		
		f.user_assign 50
		assert_equal(1, c.value)
		
		f.user_assign 100
		assert_equal(11, c.value)
	end
	
	def test_constraintparser_extended
		cp = ConstraintParser.new
		c,f = cp.parse "9*c=5*(f-32)"
		
		f.user_assign 32
		assert_equal(0, c.value)
		
		f.user_assign 100
		assert_equal(37, c.value)
	end
end
