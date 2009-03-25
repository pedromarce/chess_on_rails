require File.dirname(__FILE__) + '/../spec_helper'

describe MoveController do 

  before(:all) do
    @controller = MoveController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end
  
  it 'should have a flash error upon an invalid move' do
    post :create, {:match_id => 3, :move => { :from_coord =>'e2', :to_coord => 'x9' }  }, {:player_id => 1}
    flash[:move_error].should include('x9 is not a valid')
    
  end
  
  def test_accepts_and_notates_move_via_coordinates
    m = matches(:paul_vs_dean)
    
    assert_equal 0, m.moves.length
  
    post :create, { :match_id => m.id, :move => {:from_coord => 'a2', :to_coord => 'a4'} }, {:player_id => m.player1.id}
    assert_response 302
    assert_nil flash[:move_error]

    assert_equal 1, m.reload.moves.length
    assert_not_nil m.moves.last.notation
  end
  
  def test_errs_if_specified_match_not_there_or_active
    post :create, { :match_id => 9, :move => {:from_coord => 'e2', :to_coord => 'e4'} }, {:player_id => 1}
    assert_not_nil flash[:move_error]
  end

  def test_cant_move_on_match_you_dont_own
    m = matches(:paul_vs_dean)
    assert_equal 0, m.moves.length

    post :create, { :match_id => m.id, :move => {:from_coord => 'e2', :to_coord => 'e4'} }, {:player_id => players(:maria).id }
    assert_not_nil flash[:move_error]
  end

  def test_cant_move_when_not_your_turn
    m = matches(:paul_vs_dean)
    assert_equal 0, m.moves.length

    post :create, { :match_id => m.id, :move => {:from_coord=>'e2', :to_coord=>'e4'} }, {:player_id => players(:dean).id }
    assert_not_nil flash[:move_error]
  end

  def test_game_over_when_checkmating_move_posted
    m = matches(:scholars_mate)	

    post :create, { :match_id => m.id, :move => { :notation => 'Qf7' } }, {:player_id => players(:chris).id }		

    assert_not_nil   m.reload.winning_player
    assert_not_equal 1, m.active
  end

  def test_non_ajax_move_posting_redirects_to_match_page
    m = matches(:paul_vs_dean)
    post :create, { :match_id => m.id, :move => {:from_coord => 'e2', :to_coord => 'e4'} }, {:player_id => players(:paul).id }
    assert_response :redirect		
  end
  
end
