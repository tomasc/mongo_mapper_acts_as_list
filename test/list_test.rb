require 'rubygems'
$:.unshift File.expand_path(File.dirname(__FILE__) + '/../lib')

require 'active_model'
require 'mongo_mapper'
require 'mongo_mapper/plugins/acts_as_list'
require 'ruby-debug'
require 'shoulda'
require 'test/unit'



# DB SETUP

MongoMapper.connection = Mongo::Connection.new('127.0.0.1', 27017)
MongoMapper.database = "mongo_mapper_acts_as_list_test"
MongoMapper.database.collections.each { |c| c.drop_indexes }

def teardown_db
  MongoMapper.database.collections.each { |coll| coll.remove }
end



# CLASS SETUP

class ListMixin
	include MongoMapper::Document

	plugin MongoMapper::Plugins::ActsAsList
	
	key :pos, Integer
	key :parent_id, Integer
	key :original_id, Integer

  acts_as_list :column => :pos, :scope => :parent_id
end

class ListMixinSub1 < ListMixin
end

class ListMixinSub2 < ListMixin
end

class ListMixinWithArrayScope
	include MongoMapper::Document
	
	plugin MongoMapper::Plugins::ActsAsList
	
	key :pos, Integer
	key :parent_id, Integer

  acts_as_list :column => :pos, :scope => [:parent_id, :original_id]
end



# TESTS

class ScopeTest < ActiveSupport::TestCase
	
	def setup
		@lm1 = ListMixin.create! :pos => 1, :parent_id => 5, :original_id => 1
		@lm2 = ListMixinWithArrayScope.create! :pos => 1, :parent_id => 5, :original_id => 1
	end
	
	def teardown
		teardown_db
	end
	
	def test_symbol_scope
		assert_equal @lm1.scope_condition, { :parent_id => 5 }
		assert_equal @lm2.scope_condition, { :parent_id => 5, :original_id => 1 }
	end
	
end



class ListTest < Test::Unit::TestCase

	  def setup
	    (1..4).each{ |counter| ListMixin.create! :pos => counter, :parent_id => 5, :original_id => counter }
	  end
	
	  def teardown
	    teardown_db
	  end
	
	  def test_reordering
	    assert_equal [1, 2, 3, 4], ListMixin.where(:parent_id => 5).sort(:pos).all.map(&:original_id)

	    ListMixin.where(:original_id => 2).first.move_lower
	    assert_equal [1, 3, 2, 4], ListMixin.where(:parent_id => 5).sort(:pos).all.map(&:original_id)
	      
	    ListMixin.where(:original_id => 2).first.move_higher
	    assert_equal [1, 2, 3, 4], ListMixin.where(:parent_id => 5).sort(:pos).all.map(&:original_id)
	      
	    ListMixin.where(:original_id => 1).first.move_to_bottom
	    assert_equal [2, 3, 4, 1], ListMixin.where(:parent_id => 5).sort(:pos).all.map(&:original_id)
	      
	    ListMixin.where(:original_id => 1).first.move_to_top
	    assert_equal [1, 2, 3, 4], ListMixin.where(:parent_id => 5).sort(:pos).all.map(&:original_id)
	      
	    ListMixin.where(:original_id => 2).first.move_to_bottom
	    assert_equal [1, 3, 4, 2], ListMixin.where(:parent_id => 5).sort(:pos).all.map(&:original_id)
	      
	    ListMixin.where(:original_id => 4).first.move_to_top
	    assert_equal [4, 1, 3, 2], ListMixin.where(:parent_id => 5).sort(:pos).all.map(&:original_id)
	  end
	
	  def test_move_to_bottom_with_next_to_last_item
	    assert_equal [1, 2, 3, 4], ListMixin.where(:parent_id => 5).sort(:pos).all.map(&:original_id)
	    ListMixin.where(:original_id => 3).first.move_to_bottom
	    assert_equal [1, 2, 4, 3], ListMixin.where(:parent_id => 5).sort(:pos).all.map(&:original_id)
	  end
	
	  def test_next_prev
	    assert_equal ListMixin.where(:original_id => 2).first, ListMixin.where(:original_id => 1).first.lower_item
	    assert_nil ListMixin.where(:original_id => 1).first.higher_item
	    assert_equal ListMixin.where(:original_id => 3).first, ListMixin.where(:original_id => 4).first.higher_item
	    assert_nil ListMixin.where(:original_id => 4).first.lower_item
	  end
	
	  def test_injection
	    item = ListMixin.new(:parent_id => 1)
	    assert_equal item.scope_condition, {:parent_id => 1}
	    assert_equal "pos", item.position_column
	  end
	
	  def test_insert
	    new = ListMixin.create(:parent_id => 20)
	    assert_equal 1, new.pos
	    assert new.first?
	    assert new.last?
	  
	    new = ListMixin.create(:parent_id => 20)
	    assert_equal 2, new.pos
	    assert !new.first?
	    assert new.last?
	  
	    new = ListMixin.create(:parent_id => 20)
	    assert_equal 3, new.pos
	    assert !new.first?
	    assert new.last?
	  
	    new = ListMixin.create(:parent_id => 0)
	    assert_equal 1, new.pos
	    assert new.first?
	    assert new.last?
	  end
	
	  def test_insert_at
	    new = ListMixin.create(:parent_id => 20)
	    assert_equal 1, new.pos
	  
	    new = ListMixin.create(:parent_id => 20)
	    assert_equal 2, new.pos
	  
	    new = ListMixin.create(:parent_id => 20)
	    assert_equal 3, new.pos
	  
	    new4 = ListMixin.create(:parent_id => 20)
	    assert_equal 4, new4.pos
	  
	    new4.insert_at(3)
	    assert_equal 3, new4.pos
	  
	    new.reload
	    assert_equal 4, new.pos
	  
	    new.insert_at(2)
	    assert_equal 2, new.pos
	  
	    new4.reload
	    assert_equal 4, new4.pos
	  
	    new5 = ListMixin.create(:parent_id => 20)
	    assert_equal 5, new5.pos
	  
	    new5.insert_at(1)
	    assert_equal 1, new5.pos
	  
	    new4.reload
	    assert_equal 5, new4.pos
	  end
	
	  def test_delete_middle
	    assert_equal [1, 2, 3, 4], ListMixin.where(:parent_id => 5).sort(:pos).all.map(&:original_id)
	  
	    ListMixin.where(:original_id => 2).first.destroy
	  
	    assert_equal [1, 3, 4], ListMixin.where(:parent_id => 5).sort(:pos).all.map(&:original_id)
	  
	    assert_equal 1, ListMixin.where(:original_id => 1).first.pos
	    assert_equal 2, ListMixin.where(:original_id => 3).first.pos
	    assert_equal 3, ListMixin.where(:original_id => 4).first.pos
	  
	    ListMixin.where(:original_id => 1).first.destroy
	  
	    assert_equal [3, 4], ListMixin.where(:parent_id => 5).sort(:pos).all.map(&:original_id)
	  
	    assert_equal 1, ListMixin.where(:original_id => 3).first.pos
	    assert_equal 2, ListMixin.where(:original_id => 4).first.pos
	  end
	
	  def test_nil_scope
	    new1, new2, new3 = ListMixin.create, ListMixin.create, ListMixin.create
	    new2.move_higher
	    assert_equal [new2, new1, new3], ListMixin.where(:parent_id => nil).sort(:pos).all
	  end
	   
	  def test_remove_from_list_should_then_fail_in_list? 
	    assert_equal true, ListMixin.where(:original_id => 1).first.in_list?
	    ListMixin.where(:original_id => 1).first.remove_from_list
	    assert_equal false, ListMixin.where(:original_id => 1).first.in_list?
	  end 
	  
	  def test_remove_from_list_should_set_position_to_nil 
	    assert_equal [1, 2, 3, 4], ListMixin.where(:parent_id => 5).sort(:pos).all.map(&:original_id)
	  
	    ListMixin.where(:original_id => 2).first.remove_from_list 
	  
	    assert_equal [2, 1, 3, 4], ListMixin.where(:parent_id => 5).sort(:pos).all.map(&:original_id)
	  
	    assert_equal 1,   ListMixin.where(:original_id => 1).first.pos
	    assert_equal nil, ListMixin.where(:original_id => 2).first.pos
	    assert_equal 2,   ListMixin.where(:original_id => 3).first.pos
	    assert_equal 3,   ListMixin.where(:original_id => 4).first.pos
	  end 

	  def test_remove_before_destroy_does_not_shift_lower_items_twice 
	    assert_equal [1, 2, 3, 4], ListMixin.where(:parent_id => 5).sort(:pos).all.map(&:original_id)
	  
	    ListMixin.where(:original_id => 2).first.remove_from_list 
	    ListMixin.where(:original_id => 2).first.destroy 
	  
	    assert_equal [1, 3, 4], ListMixin.where(:parent_id => 5).sort(:pos).all.map(&:original_id)
	  
	    assert_equal 1, ListMixin.where(:original_id => 1).first.pos
	    assert_equal 2, ListMixin.where(:original_id => 3).first.pos
	    assert_equal 3, ListMixin.where(:original_id => 4).first.pos
	  end 
  
end

class ListSubTest < Test::Unit::TestCase

  def setup
    (1..4).each{ |i| ((i % 2 == 1) ? ListMixinSub1 : ListMixinSub2).create! :pos => i, :parent_id => 5000, :original_id => i }
  end

	def teardown
    teardown_db
  end

  def test_reordering
    assert_equal [1, 2, 3, 4], ListMixin.where(:parent_id => 5000).sort(:pos).all.map(&:original_id)

    ListMixin.where(:original_id => 2).first.move_lower
    assert_equal [1, 3, 2, 4], ListMixin.where(:parent_id => 5000).sort(:pos).all.map(&:original_id)
      
    ListMixin.where(:original_id => 2).first.move_higher
    assert_equal [1, 2, 3, 4], ListMixin.where(:parent_id => 5000).sort(:pos).all.map(&:original_id)
      
    ListMixin.where(:original_id => 1).first.move_to_bottom
    assert_equal [2, 3, 4, 1], ListMixin.where(:parent_id => 5000).sort(:pos).all.map(&:original_id)

    ListMixin.where(:original_id => 1).first.move_to_top
    assert_equal [1, 2, 3, 4], ListMixin.where(:parent_id => 5000).sort(:pos).all.map(&:original_id)
      
    ListMixin.where(:original_id => 2).first.move_to_bottom
    assert_equal [1, 3, 4, 2], ListMixin.where(:parent_id => 5000).sort(:pos).all.map(&:original_id)
      
    ListMixin.where(:original_id => 4).first.move_to_top
    assert_equal [4, 1, 3, 2], ListMixin.where(:parent_id => 5000).sort(:pos).all.map(&:original_id)
  end

  def test_move_to_bottom_with_next_to_last_item
    assert_equal [1, 2, 3, 4], ListMixin.where(:parent_id => 5000).sort(:pos).all.map(&:original_id)
    ListMixin.where(:original_id => 3).first.move_to_bottom
    assert_equal [1, 2, 4, 3], ListMixin.where(:parent_id => 5000).sort(:pos).all.map(&:original_id)
  end

  def test_next_prev
    assert_equal ListMixin.where(:original_id => 2).first, ListMixin.where(:original_id => 1).first.lower_item
    assert_nil ListMixin.where(:original_id => 1).first.higher_item
    assert_equal ListMixin.where(:original_id => 3).first, ListMixin.where(:original_id => 4).first.higher_item
    assert_nil ListMixin.where(:original_id => 4).first.lower_item
  end

  def test_injection
    item = ListMixin.new(:parent_id => 1)
    assert_equal item.scope_condition, { :parent_id => 1 }
    assert_equal "pos", item.position_column
  end

  def test_insert_at
    new = ListMixin.create(:parent_id => 20)
    assert_equal 1, new.pos
 
    new = ListMixinSub1.create(:parent_id => 20)
    assert_equal 2, new.pos
 
    new = ListMixinSub2.create(:parent_id => 20)
    assert_equal 3, new.pos
 
    new4 = ListMixin.create(:parent_id => 20)
    assert_equal 4, new4.pos
 
    new4.insert_at(3)
    assert_equal 3, new4.pos
 
    new.reload
    assert_equal 4, new.pos
 
    new.insert_at(2)
    assert_equal 2, new.pos
 
    new4.reload
    assert_equal 4, new4.pos
 
    new5 = ListMixinSub1.create(:parent_id => 20)
    assert_equal 5, new5.pos
 
    new5.insert_at(1)
    assert_equal 1, new5.pos
 
    new4.reload
    assert_equal 5, new4.pos
  end

  def test_delete_middle
    assert_equal [1, 2, 3, 4], ListMixin.where(:parent_id => 5000).sort(:pos).all.map(&:original_id)
 
    ListMixin.where(:original_id => 2).first.destroy
 
    assert_equal [1, 3, 4], ListMixin.where(:parent_id => 5000).sort(:pos).all.map(&:original_id)
 
    assert_equal 1, ListMixin.where(:original_id => 1).first.pos
    assert_equal 2, ListMixin.where(:original_id => 3).first.pos
    assert_equal 3, ListMixin.where(:original_id => 4).first.pos
 
    ListMixin.where(:original_id => 1).first.destroy
 
    assert_equal [3, 4], ListMixin.where(:parent_id => 5000).sort(:pos).all.map(&:original_id)
 
    assert_equal 1, ListMixin.where(:original_id => 3).first.pos
    assert_equal 2, ListMixin.where(:original_id => 4).first.pos
  end

end
