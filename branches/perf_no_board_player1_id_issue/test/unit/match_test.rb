require File.dirname(__FILE__) + '/../test_helper'
require 'ruby-debug'

class MatchTest < ActiveSupport::TestCase

  fixtures :players
  
  def test_newly_minted_match_has_live_pieces
      m = Match.new( :player1 => players(:dean), :player2 => players(:chris)  )
      m.save!
      assert_not_nil m.pieces
      assert_not_nil m.pieces[0]
  end
  
  def test_pieces_are_updated_when_you_move

      m = Match.new( :player1 => players(:dean), :player2 => players(:chris)  )
      m.save!
      m.moves << Move.new( :notation => 'e4' )
      assert_not_nil m.pieces.find{ |p| p.position == 'e4'}
      assert_nil     m.pieces.find{ |p| p.position == 'e2'}

      m.moves << Move.new( :notation => 'd5' )
      assert_not_nil m.pieces.find{ |p| p.position == 'd5'}
      assert_nil     m.pieces.find{ |p| p.position == 'd7'}
      assert_equal   'd7', m.moves.last.from_coord
  end  

  def test_32_pieces_on_chess_initial_board
    assert_equal 32, matches(:unstarted_match).board.pieces.length
  end

  def test_first_player_to_move_is_player1
    m1 = matches(:unstarted_match)

    #debugger
    assert_equal 2, m1.attributes['player1_id']
    
    assert_not_nil Player.find( m1.attributes['player1_id'] )
    
    assert_not_nil m1.player1
    
    assert_equal 0, m1.moves.length
    
    assert m1.turn_of?( m1.player1)
  end

  #tests related to game play
  def test_next_to_move_alternates_sides
    m1 = matches(:unstarted_match)
    assert_equal 0, m1.moves.count
    assert m1.turn_of?( m1.player1 )
    
    m1.moves << Move.new(:from_coord=>'b2', :to_coord=>'b4' )
    
    assert m1.turn_of?( m1.player2 )

  end
      
  def test_knows_what_side_player_is_on
    m1 = matches(:paul_vs_dean)
    debugger
    assert_equal players(:paul).id, m1.player1.id
    assert_equal players(:dean).id, m1.player2.id
    
    assert_equal :white, m1.side_of( players(:paul) )
    assert_equal :black, m1.side_of( players(:dean) )
    assert_equal :white, m1.opposite_side_of( players(:dean) )		
  end

  def test_knows_whose_turn_it_is
    m1 = matches(:paul_vs_dean)
    assert_equal 0, m1.moves.count

    assert m1.turn_of?( players(:paul) )
  end

  def test_shows_lineup
    assert_equal 'Paul vs. Dean', matches(:paul_vs_dean).lineup
    assert_equal 'Dean vs. Paul', matches(:dean_vs_paul).lineup
  end

  def test_player_can_resign
    #player1
    m1 = matches(:paul_vs_dean)
    m1.resign( players(:paul) )
    assert_not_nil m1.winning_player
    assert_equal players(:dean), m1.winning_player
  end

end
  