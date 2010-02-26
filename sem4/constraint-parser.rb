#!/usr/bin/env ruby

require 'logger'

# We will use the constraint networks we defined in the previous seminar.
require 'constraint_networks'

# 1. Parsing a recursively defined language. The code below defines a
# recursive-descent parser, which can parse a language and create a
# syntax tree for the elements which are part of the language. This is
# used below to implement a parser for a simple dice-rolling language. 

# Make sure you understand the basic structure of how the parser
# works. Add logging output as appropriate (see constraint_networks.rb
# from the previous seminar for information on how)

# Next, you will model an equation system, only now using a more
# natural syntax.

class Rule
  # A rule is created through the rule method of the Parser class, like so:
  #   rule :term do
  #     match(:term, '*', :dice) {|a, _, b| a * b }
  #     match(:term, '/', :dice) {|a, _, b| a / b }
  #     match(:dice)
  #   end
  
  Match = Struct.new :pattern, :block
  
  def initialize(name, parser)
    # The name of the expressions this rule matches
    @logger=Logger.new(STDOUT)
    @name = name
    # We need the parser to recursively parse sub-expressions
    # occurring within the pattern of the match objects associated
    # with this rule
    @parser = parser
    @matches = []
    # Left-recursive matches, which in the first two cases 
    @lrmatches = []
  end
  
  # Add a matching expression to this rule, as in this example:
  #     match(:term, '*', :dice) {|a, _, b| a * b }
  # The arguments to 'match' describe the constituents of this expression.
  
  def match(*pattern, &block)
    match = Match.new(pattern, block)
    # If the pattern is left-recursive, then add it to the left-recursive set
    if pattern[0] == @name
      pattern.shift
      @lrmatches << match
    else
      @matches << match
    end
  end
  
  
  def parse
    # Try non-left-recursive matches first, to avoid infinite recursion
    match_result = try_matches(@matches)
    return nil unless match_result
    loop do
      result = try_matches(@lrmatches, match_result)
      return match_result unless result
      match_result = result
    end
  end
  
  

  private
  
  # Try out all matching patterns of this rule
  def try_matches(matches, pre_result = nil)
    match_result = nil
    # Begin at the current position in the input string of the parser
    start = @parser.pos
    matches.each do |match|
      # pre_result is a previously available result from evaluating expressions
      result = pre_result ? [pre_result] : []

      # We iterate through the parts of the pattern, which may be
      # [:expr,'*',:term]
      match.pattern.each_with_index do |token,index|
        
        # If this "token" is a compound term, add the result of
        # parsing it to the "result" array
        
        if @parser.rules[token]
          result << @parser.rules[token].parse
          unless result.last
            result = nil
            break
          end
          @logger.debug("Matched '#{@name} = #{match.pattern[index..-1].inspect}'")
        else
          # Otherwise, we consume the token as part of applying this rule
          nt = @parser.expect(token)
          if nt
            result << nt
            if @lrmatches.include?(match.pattern) then
              pattern=[@name]+match.pattern
            else
              pattern=match.pattern
            end
            @logger.debug("Matched token '#{nt}' as part of rule '#{@name} <= #{pattern.inspect}'")
          else
            result = nil
            break
          end
        end
      end
      if result
        if match.block
          match_result = match.block.call(*result)
        else
          match_result = result[0]
        end
        @logger.debug("'#{@parser.string[start..@parser.pos-1]}' matched '#{@name}' and generated '#{match_result.inspect}'") unless match_result.nil?
        break
      else
        # If this rule did not match the current token list, move
        # back to the scan position of the last match
        @parser.pos = start
      end
    end
    
    return match_result
  end
end


class Parser


  attr_accessor :pos
  attr_reader :rules,:string
  class ParseError < RuntimeError; end
  def initialize(language_name, &block)
    @logger=Logger.new(STDOUT)
    @lex_tokens = []
    @rules = {}
    @start = nil
    @language_name=language_name
    instance_eval(&block)
  end
  
  # Tokenize the string into small pieces
  def tokenize(string)
    @tokens = []
    @string=string.clone
    until string.empty?
      # Unless any of the valid tokens of our language are the prefix of
      # 'string', we fail with an exception
      raise ParseError, "unable to lex '#{string}" unless @lex_tokens.any? do |tok|
        match = tok.pattern.match(string)
        # The regular expression of a token has matched the beginning of 'string'
        if match
          @logger.debug("Token #{match[0]} consumed")
          # Also, evaluate this expression by using the block
          # associated with the token
          @tokens << tok.block.call(match.to_s) if tok.block
          # consume the match and proceed with the rest of the string
          string = match.post_match
          true
        else
          # this token pattern did not match, try the next
          false
        end # if
      end # raise
    end # until
  end
  
  def parse(string)
    # First, split the string according to the "token" instructions given to Parser
    tokenize(string)
    # Now, @tokens contains all tokens that are to be parsed. 

    # These variables are used to match if the total number of tokens
    # are consumed by the parser
    @pos = 0
    @max_pos = 0
    @expected = []
    # Parse (and evaluate) the tokens received
    result = @start.parse
    # If there are unparsed extra tokens, signal error
    if @pos != @tokens.size
      raise ParseError, "Parse error. expected: '#{@expected.join(', ')}', found '#{@tokens[@max_pos]}'"
    end
    return result
  end
  
  def next_token
    @pos += 1
    return @tokens[@pos - 1]
  end

  # Return the next token in the queue
  def expect(tok)
    t = next_token
    if @pos - 1 > @max_pos
      @max_pos = @pos - 1
      @expected = []
    end
    return t if tok === t
    @expected << tok if @max_pos == @pos - 1 && !@expected.include?(tok)
    return nil
  end
  
  def to_s
    "Parser for #{@language_name}"
  end

  private
  
  LexToken = Struct.new(:pattern, :block)
  
  def token(pattern, &block)
    @lex_tokens << LexToken.new(Regexp.new('\\A' + pattern.source), block)
  end
  
  def start(name, &block)
    rule(name, &block)
    @start = @rules[name]
  end
  
  def rule(name,&block)
    @current_rule = Rule.new(name, self)
    @rules[name] = @current_rule
    instance_eval &block
    @current_rule = nil
  end
  
  def match(*pattern, &block)
    @current_rule.send(:match,*pattern,&block)
  end

end

######################################################################################
#
# This part defines the dice language
#
######################################################################################

class DiceRoller

        
  def DiceRoller.roll(times, sides)
    (1..times).inject(0) {|sum, _| sum + rand(sides) + 1 }
  end
  
  def initialize
    @diceParser = Parser.new("dice roller") do
      token(/\s+/)
      token(/\d+/) {|m| m.to_i }
      token(/./) {|m| m }
      
      start :expr do 
        match(:expr, '+', :term) {|a, _, b| a + b }
        match(:expr, '-', :term) {|a, _, b| a - b }
        match(:term)
      end
      
      rule :term do 
        match(:term, '*', :dice) {|a, _, b| a * b }
        match(:term, '/', :dice) {|a, _, b| a / b }
        match(:dice)
      end

      rule :dice do
        match(:atom, 'd', :sides) {|a, _, b| DiceRoller.roll(a, b) }
        match('d', :sides) {|_, b| DiceRoller.roll(1, b) }
        match(:atom)
      end
      
      rule :sides do
        match('%') { 100 }
        match(:atom)
      end
      
      rule :atom do
        # Match the result of evaluating an integer expression, which should be an Integer
        match(Integer)
        match('(', :expr, ')') {|_, a, _| a }
      end
    end
  end
  
  def done(str)
    ["quit","exit","bye",""].include?(str.chomp)
  end
  
  def roll
    print "[diceroller] "
    str=gets
    if done(str) then
      puts "Bye."
    else
      puts "=> #{@diceParser.parse str}"
      roll
    end
  end
end

# Test: 

# irb(main):1696:0> DiceRoller.new.roll
# [diceroller] 1+3
# => 4
# [diceroller] 1+d4
# => 2
# [diceroller] 1+d4
# => 3
# [diceroller] (2+8*d20)*3d6
# => 306

# ********** TASK *************** 

# Someone has tried to implement a parser and constraint network
# generator based on the parser above. However, there seem to be
# something missing or wrong with the code which prevents you from
# using it directly. Your task therefore is to finish what someone
# else has started and to make the test case below work.


class ConstraintParser < Parser
  class Variable; end

  def initialize
    @connectors={}
    @parser=super("constraints") do
      token(/\s+/)
      token(/[[:alpha:]]+/) do |connector|
        # Add a variable to the set of connectors, if there is not
        # already one by the same name defined. We want all
        # occurrences of the same variable to denote the same object.
        @connectors[connector] ||= Connector.new(connector)
      end
      token(/\d+/) do |constant|
        # Add a constant to the set of connectors. Again, only if necessary.
        @connectors[constant] ||= ConstantConnector.new(constant,constant.to_i) 
      end
      token(/./) { |m| m }
      
      start :statement do

        match(:expr, '=', :term) do |lh, _, rh| 
          replace_conn(lh, rh)
          # Return all variables in the equation apart from the ones
          # generated by the parser.
          @connectors.values.reject do |conn|
            # Remove all constants and all where the name does not
            # match the regular expression /^\w+$/, which we consider
            # to be the pattern describing "proper" variable
            # names. The expression /^\w+$/ matches strings which
            # *only* contains a sequence of one or more (+) characters
            # which are considered word characters (\w). 
            conn.is_a?(ConstantConnector) or (not (/^\w+$/ =~ conn.name))
            end
        end

      end

      rule :expr do

        match(:expr, '+', :term) do |a, _, b| 
          conn_a,conn_b,conn_c=get_connectors(a,'+',b)
          Adder.new(conn_a,conn_b,conn_c)
        end

        match(:expr, '-', :term) do |a, _, b|
          conn_a,conn_b,conn_c=get_connectors(a,'-',b)
          # a-b=c <=> a=b+c
          Adder.new(conn_b,conn_c,conn_a)
        end

        match(:term)

      end
      
      rule :term do
        
        match(:term, '*', :atom) do |a, _, b|
          conn_a,conn_b,conn_c=get_connectors(a,'*',b)
          Multiplier.new(conn_a,conn_b,conn_c)
        end
        
        match(:term, '/', :atom) do |a, _, b|
          conn_a,conn_b,conn_c=get_connectors(a,'/',b)
          # a/b=c <=> b*c=a
          Multiplier.new(conn_b,conn_c,conn_a)
        end
        
        match(:atom)
        
      end
    
      rule :atom do
        match(Connector)
        match('(', :expr, ')') {|_, a, _| a }
      end
    end
  end

  # Retrieve and generate connectors for the binary constraints 
  def get_connectors(conn_a,op,conn_b)
    name_c="#{conn_a.name}#{op}#{conn_b.name}"
    conn_c=Connector.new(name_c)
    @connectors[name_c]=conn_c
    [conn_a,conn_b,conn_c]
  end

  # Unify the connectors on the left and right hand side of an equality
  def replace_conn(lh,rh)
    lh_conn,rh_conn=[get_connector(lh),get_connector(rh)]
    conn,exp=[nil,nil]
    if rh.is_a?(ArithmeticConstraint) then
      exp,conn=rh,lh_conn
      @connectors.delete(rh_conn.name)
    else if lh.is_a?(ArithmeticConstraint) then
           exp,conn=lh,rh_conn
           @connectors.delete(lh_conn.name)
         end
    end
    exp.out=conn
    conn.add_constraint(exp)
  end
  
  def parse(str)
    @connectors={}
    super(str)
  end

end


# Test:

# cp=ConstraintParser.new
# c,f=cp.parse "9*c=5*(f-32)"

# irb(main):827:0> f.user_assign 0
# D, [2007-03-03T15:16:56.409386 #18327] DEBUG -- : f lost value
# D, [2007-03-03T15:16:56.457694 #18327] DEBUG -- : Notifying f-32 + 32 == f
# D, [2007-03-03T15:16:56.457973 #18327] DEBUG -- : f-32 ignored request
# D, [2007-03-03T15:16:56.458114 #18327] DEBUG -- : 32 ignored request
# D, [2007-03-03T15:16:56.458298 #18327] DEBUG -- : f got new value: 0
# D, [2007-03-03T15:16:56.458455 #18327] DEBUG -- : f-32 + 32 == f : f-32 updated
# D, [2007-03-03T15:16:56.458563 #18327] DEBUG -- : f-32 got new value: -32
# D, [2007-03-03T15:16:56.458697 #18327] DEBUG -- : f-32 * 5 == 9c : 9c updated
# D, [2007-03-03T15:16:56.458801 #18327] DEBUG -- : 9c got new value: -160
# D, [2007-03-03T15:16:56.458938 #18327] DEBUG -- : c * 9 == 9c : c updated
# D, [2007-03-03T15:16:56.459051 #18327] DEBUG -- : c got new value: -18
# "ok"
# irb(main):828:0> f.user_assign 100
# D, [2007-03-03T15:17:09.637193 #18327] DEBUG -- : f lost value
# D, [2007-03-03T15:17:09.674361 #18327] DEBUG -- : Notifying f-32 + 32 == f
# D, [2007-03-03T15:17:09.674802 #18327] DEBUG -- : f-32 lost value
# D, [2007-03-03T15:17:09.675038 #18327] DEBUG -- : Notifying f-32 * 5 == 9c
# D, [2007-03-03T15:17:09.675543 #18327] DEBUG -- : 5 ignored request
# D, [2007-03-03T15:17:09.675709 #18327] DEBUG -- : 9c lost value
# D, [2007-03-03T15:17:09.675852 #18327] DEBUG -- : Notifying c * 9 == 9c
# D, [2007-03-03T15:17:09.675977 #18327] DEBUG -- : c lost value
# D, [2007-03-03T15:17:09.676106 #18327] DEBUG -- : 9 ignored request
# D, [2007-03-03T15:17:09.676264 #18327] DEBUG -- : 32 ignored request
# D, [2007-03-03T15:17:09.676389 #18327] DEBUG -- : f got new value: 100
# D, [2007-03-03T15:17:09.676545 #18327] DEBUG -- : f-32 + 32 == f : f-32 updated
# D, [2007-03-03T15:17:09.676654 #18327] DEBUG -- : f-32 got new value: 68
# D, [2007-03-03T15:17:09.676843 #18327] DEBUG -- : f-32 * 5 == 9c : 9c updated
# D, [2007-03-03T15:17:09.676951 #18327] DEBUG -- : 9c got new value: 340
# D, [2007-03-03T15:17:09.677089 #18327] DEBUG -- : c * 9 == 9c : c updated
# D, [2007-03-03T15:17:09.740035 #18327] DEBUG -- : c got new value: 37
# "ok"

