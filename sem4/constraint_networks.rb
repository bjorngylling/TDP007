#!/usr/bin/env ruby

require 'logger'

# ----------------------------------------------------------------------------
#  Bidirectional constraint network for arithmetic constraints
# ----------------------------------------------------------------------------

module PrettyPrintCN

  # To make printouts of connector objects easier, we define the
  # inspect method so that it returns the value of to_s. This method
  # is used by Ruby when we display objects in irb. By defining this
  # method in a module, we can include it in several classes that are
  # not related by inheritance.

  def inspect
    "#<#{self.class}: #{to_s}>"
  end

end

# This is the base class for Adder and Multiplier.

class ArithmeticConstraint

  include PrettyPrintCN

  attr_accessor :a,:b,:out
  attr_reader :logger,:op,:inverse_op

  def initialize(a, b, out)
    @logger=Logger.new(STDOUT)
    @logger.level = Logger::ERROR
    @a,@b,@out=[a,b,out]
    [a,b,out].each { |x| x.add_constraint(self) }
  end
  
  def to_s
    "#{a} #{op} #{b} == #{out}"
  end
  
  def new_value(connector)
		if [a,b,out].include?(connector)
			if a.has_value? and b.has_value? and (not out.has_value?)
				# Inputs changed, so update output to be the sum of the inputs
				# "send" means that we send a message, op in this case, to an
				# object.
				val=a.value.send(op, b.value)
				logger.debug("#{self} : #{out} updated")
				out.assign(val, self)
			elsif out.has_value? and (a.has_value? or b.has_value?) and (not (a.has_value? and b.has_value?))
				# Expand the calculation to allow for inverse calculation if we know the "answer" already
				if a.has_value?
					val=out.value.send(inverse_op, a.value)
					logger.debug("#{self} : #{b} updated")
					b.assign(val, self)
				else
					val=out.value.send(inverse_op, b.value)	
					logger.debug("#{self} : #{a} updated")
					a.assign(val, self)
				end
			end
		end
		self
  end
  
  # A connector lost its value, so propagate this information to all
  # others
  def lost_value(connector)
    ([a,b,out]-[connector]).each { |connector| connector.forget_value(self) }
  end
  
end

class Adder < ArithmeticConstraint
  
  def initialize(*args)
    super(*args)
    @op,@inverse_op=[:+,:-]
  end
end

class Multiplier < ArithmeticConstraint

  def initialize(*args)
    super(*args)
    @op,@inverse_op=[:*,:/]
  end
    
end

class ContradictionException < Exception
end

# This is the bidirectional connector which may be part of a constraint network.

class Connector
    
  include PrettyPrintCN

  attr_accessor :name,:value

  def initialize(name, value=false)
    self.name=name
    @has_value=(not value.eql?(false))
    @value=value
    @informant=false
    @constraints=[]
    @logger=Logger.new(STDOUT)
    @logger.level = Logger::ERROR
  end

  def add_constraint(c)
    @constraints << c
  end
    
  # Values may not be set if the connector already has a value, unless
  # the old value is retracted.
  def forget_value(retractor)
    if @informant==retractor then
      @has_value=false
      @value=false
      @informant=false
      @logger.debug("#{self} lost value")
      others=(@constraints-[retractor])
      @logger.debug("Notifying #{others}") unless others == []
      others.each { |c| c.lost_value(self) }
      "ok"
    else
      @logger.debug("#{self} ignored request")
    end
  end

  def has_value?
    @has_value
  end
  
  # The user may use this procedure to set values
  def user_assign(value)
    forget_value("user")
    assign value,"user"
  end
  
  def assign(v,setter)
      if not has_value? then
        @logger.debug("#{name} got new value: #{v}")
        @value=v
        @has_value=true
        @informant=setter
        (@constraints-[setter]).each { |c| c.new_value(self)}
        "ok"
      else
        if value != v then
          raise ContradictionException.new("#{name} already has value #{value}.\nCannot assign #{name} to #{v}")
      end
    end
  end
  
  def to_s
    name
  end

end

class ConstantConnector < Connector
  
  def initialize(name, value)
    super(name, value)
    if not has_value?
      @logger.warn "Constant #{name} has no value!"
    end
  end
  
  def value=(val)
    raise ContradictionException.new("Cannot assign a constant a value!")
  end
end

# ----------------------------------------------------------------------------
#  Assignment
# ----------------------------------------------------------------------------

# Uppgift 1 inför fjärde seminariet innebär två saker:
# - Först ska ni skriva enhetstester för Adder och Multiplier. Det är inte
#   helt säkert att de funkar som de ska. Om ni med era tester upptäcker
#   fel ska ni dessutom korrigera Adder och Multiplier.
# - Med hjälp av Adder och Multiplier m.m. ska ni sedan bygga ett nätverk som
#   kan omvandla temperaturer mellan Celsius och Fahrenheit. (Om ni vill
#   får ni ta en annan ekvation som är ungefär lika komplicerad.)

# Ett tips är att skapa en funktion celsius2fahrenheit som returnerar
# två Connectors. Dessa två motsvarar Celsius respektive Fahrenheit och 
# kan användas för att mata in temperatur i den ena eller andra skalan.

def celsius2fahrenheit
	# Create our celsius and fahrenheit connectors
	c = Connector.new("c")
  f = Connector.new("f")
  
  # Create our constant value connectors
	c9 = ConstantConnector.new("c9", 9)
	c5 = ConstantConnector.new("c5", 5)
	c32 = ConstantConnector.new("c32", 32)
	
	# Create the connectors needed to link the gates
	middle = Connector.new("middle")
	right_sub = Connector.new("right_sub")
	
	# Link it all together
	Multiplier.new(c9, c, middle)
	Adder.new(c32, right_sub, f)
	Multiplier.new(c5, right_sub, middle)
	
	return c, f
end
