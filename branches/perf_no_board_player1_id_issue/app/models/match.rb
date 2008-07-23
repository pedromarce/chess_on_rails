class Match < ActiveRecord::Base

  SIDES = [  ['White', '1'], ['Black', '2']  ]
  
  belongs_to :player1,	:class_name => 'Player'
  belongs_to :player2,	:class_name => 'Player'
  
  belongs_to :winning_player, :class_name => 'Player', :foreign_key => 'winning_player'
  
  has_many :moves, :order => 'created_at ASC', :after_add => :recalc_board_and_check_for_checkmate

  serialize :pieces
  
  def before_create
    self[:pieces] = Chess.initial_pieces
  end
  
  def self.new_for( plyr1, plyr2, plyr2_side )
    plyr1, plyr2 = [plyr2, plyr1] if plyr2_side == '1'
    Match.new( :player1 => plyr1, :player2 => plyr2 )
  end
  
  def recalc_board_and_check_for_checkmate(last_move)
    #update internal representation of the board
    play_move! last_move
    
    other_guy = (last_move.side == :black ? :white : :black)

    checkmate_by( last_move.side ) if in_checkmate?( other_guy )
  end
  
  #NOTE here to ensure that the pieces array is initialized
  def board
    unless pieces
      #in test mode we dont store pieces in fixtures (yet) so we allow the repopulation as a convenience
      raise StandardError, "Recalculating board - why were your pieces not initialized ?" unless RAILS_ENV == 'test'
      self[:pieces] = Chess.initial_pieces
      moves.each{ |m| play_move!(m) } #brings pieces up to date
    end
    self
  end
  
  def play_move!( m )
    #kill any existing piece we're moving onto or capturing enpassant
    pieces.reject!{ |p| (p.position == m.to_coord) || (p.position == m.captured_piece_coord) }	
    
    #move to that square
    piece_moved = nil
    pieces.each{ |p| p.position = m.to_coord and piece_moved = p if p.position==m.from_coord }
    
    #reflect castling
    if m.castled==1
      castling_rank = m.to_coord[1].chr
      [['g', 'f', 'h'], ['c', 'd', 'a']].each do |king_file, rook_file, orig_rook_file|
        #update the position of the rook if we landed on the kings castling square
        pieces.each do |p|
          p.position = "#{rook_file}#{castling_rank}" if m.to_coord[0].chr==king_file && p.position=="#{orig_rook_file}#{castling_rank}"
        end
      end
    end
    
    #reflect promotion
    piece_moved.promote!( Move::NOTATION_TO_ROLE_MAP[ m.promotion_choice ] ) if piece_moved && piece_moved.promotable? 
    
    self
  end
  
  def turn_of?( plyr )	
    self.next_to_move == side_of(plyr)
  end

  def next_to_move
    (moves.count & 1 == 0) ? :white : :black
  end

  def side_of( plyr ) 
    return :white if plyr == player1
    return :black if plyr == player2
  end

  def opposite_side_of( plyr )
    side_of(plyr) == :white ? :black : :white
  end
  
  def piece_at(pos)
    p = board.pieces.find { |piece| piece.position == pos }
  end
  
  def [] ( pos ) 
    piece_at(pos)
  end
  
  def side_occupying(pos)
    p = piece_at(pos)
    return nil if !p 
    return p.side
  end
  
  def sister_piece_of( piece )
    p = pieces.find { |p| (p.side == piece.side) && (p.role == piece.role ) && (p.position != piece.position) }
  end

  def lineup
    "#{player1.name} vs. #{player2.name}"
  end

  def resign( plyr )
    self.result, self.active = ['Resigned', 0]
    self.winning_player = (plyr == player1) ? player2 : player1
    save!
  end

  def checkmate_by( side )
    self.result, self.active = ['Checkmate', 0]
    self.winning_player = (side == :white ? player1 : player2 )
    save!
  end
    
  def in_check?( side )
    king_to_check = pieces.find{ |p| p.role=='king' && p.side == side }
    
    pieces.select { |p| p.side != side }.each do |attacker|
      return true if attacker.allowed_moves( self ).include?( king_to_check.position )
    end
    return false
  end
  
  def is_en_passant_capture?( from_coord, to_coord ) 
  
    to_rank, to_file = to_coord[1].chr, to_coord[0].chr
    return false unless p = piece_at( from_coord )
    
    capture_rank, advanced_pawn_rank, original_pawn_rank = (p.side==:white) ? %w{ 6 5 7 } : %w{ 3 4 2 }
    possible_advanced_pawn = piece_at( to_file + advanced_pawn_rank )
    
    #if behind a pawn
    if (to_rank == capture_rank) && possible_advanced_pawn && (possible_advanced_pawn.role=='pawn') 
      #and that pawn was doubly (not singly) advanced
      moves.find_by_from_coord_and_to_coord( ( to_file + original_pawn_rank ) , possible_advanced_pawn.position ) != nil
    else
      return false
    end
    
  end
  
  #simplest logic here - if theres a move you're allowed which gets you out of check, you're not in checkmate
  #contrast with more intelligent Capture/Block/Evade strategy
  def in_checkmate?( side )
    return false unless in_check?( side )
    
    way_out = false
    return false
    
    #TODO reimplement this using new board functionality
  end
end
