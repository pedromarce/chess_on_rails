# A Board is a snapshot of a match at a moment in time, implemented as a hash
# whose keys are (symbol) positions and whose values are pieces
class Board < Hash
  extend ActiveSupport::Memoizable

  attr_accessor :last_move, :piece_moved, :en_passant_square

  attr_accessor_with_default :side_to_move, :white

  attr_accessor_with_default :white_can_castle_kingside,  true
  attr_accessor_with_default :white_can_castle_queenside, true

  attr_accessor_with_default :black_can_castle_kingside,  true
  attr_accessor_with_default :black_can_castle_queenside, true

  attr_accessor_with_default :graveyard, []

  def [] x;  x = x.to_sym; super ; end
  
  def kill at_position
    return unless self[at_position]
    graveyard << self.delete(at_position)
  end
  
  def dup *args
    b2 = super
    b2.graveyard = self.graveyard.dup
    [[:white, :king], [:white, :queen], [:black, :king], [:black, :queen]].each do |side, flank|
      b2.send(:"#{side}_can_castle_#{flank}side=",  self.send("#{side}_can_castle_#{flank}side"))
    end
    b2
  end

  # updates internals with a given move played
  # Dereferences any existing piece we're moving onto or capturing enpassant
  # Updates our EP square or nils it out
  def play_move!( m )
    
    m = Move.new(m) if m.kind_of?(Hash)
    self.kill( m.captured_piece_coord_sym || m.to_coord_sym )

    self.last_move = m
    self.piece_moved = self.delete(m.from_coord_sym)
    self[m.to_coord_sym] = piece_moved

    if m.castled==1
      castling_rank = m.to_coord_sym.rank.to_s
      [['g', 'f', 'h'], ['c', 'd', 'a']].each do |king_file, new_rook_file, orig_rook_file|
        #update the position of the rook corresponding to the square the king landed on
    	if m.to_coord_sym.file == king_file 
    	   rook = self.delete("#{orig_rook_file}#{castling_rank}".to_sym)
    	   self["#{new_rook_file}#{castling_rank}".to_sym] = rook
    	end
      end
    end
    
    #TODO investigate why this method is getting called multiply per moves << Move.new
    return unless piece_moved

    update_en_passant_square! m
    update_castling! m

    #reflect promotion
    if piece_moved && piece_moved.function == :pawn && m.to_coord_sym.rank == piece_moved.promotion_rank
      self.delete(m.to_coord_sym)
      self[m.to_coord_sym] = Queen.new(piece_moved.side, :promoted)
    end
    
    self
  end

  # When a move is made, either sets or clears the square on which an en_passant capture is available
  def update_en_passant_square! move
    ep_from_rank, ep_rank, ep_to_rank  = Chess::EN_PASSANT[ piece_moved.side ]
    if piece_moved.function == :pawn &&
       move.from_coord_sym.rank == ep_from_rank && 
       move.to_coord_sym.rank == ep_to_rank 
      @en_passant_square = ( move.from_coord_sym.file + ep_rank.to_s ).to_sym
    else
      @en_passant_square = nil
    end
  end

  def update_castling! m
    case piece_moved.function
    when :king
      self.send(:"#{piece_moved.side}_can_castle_kingside=",  false)
      self.send(:"#{piece_moved.side}_can_castle_queenside=", false)
    when :rook
      self.send(:"#{piece_moved.side}_can_castle_#{m.from_coord.flank}side=",  false)
    end
  end

  def toggle_side_to_move! ; self.side_to_move = side_to_move.opposite; self; end

  # returns a copy of self with move played
  # examples: 
  # # block style for instant answer
  # woot = board.consider_move( Move.new(...) ){ in_check?( :black ) } 
  # # get the board for future consideration
  # new = board.consider_move( Move.new(...) )
  def consider_move(m, &block)
    considered = self.dup 
    considered.play_move!(m)
    return considered unless block_given?
    yield  considered
  end
  
  def in_check?( side )
    king_pos, king  = detect do |pos, piece| 
      piece && piece.function==:king && piece.side == side 
    end

    assassin = self.detect do |position, attacker|
      attacker && (attacker.side != side) &&
      attacker.allowed_moves(self).include?(king_pos.to_sym)
    end

    !! assassin
  end
  memoize :in_check?

  # Checkmate detection done with only the simplest logic:
  #   for all moves you can do
  #     - if you're not in check at the end of it 
  #     - you've not been checkmated
  # contrast with more intelligent Capture/Block/Evade strategy
  def in_checkmate?( side )

    return false unless in_check?( side )
    
    way_out = false
    each_pair do |pos, piece|
      next if piece.side != side
      return false if way_out
      piece.allowed_moves(self).each do |mv|
        consider_move( Move.new( :from_coord => pos, :to_coord => mv ) ) do |b|
          way_out = ! b.in_check?( side )
        end
      end
    end
    return !way_out
  end
  memoize :in_checkmate?

  #provides a format for tracing
  def to_s( for_black = false )
    output = '' # ' ' * (8 * 8 * 2) #spaces or newlines after each 
    ranks  = %w{ 8 7 6 5 4 3 2 1 }
    files  = %w{ a b c d e f g h } 
    (ranks.reverse! and files.reverse!) if for_black
    last_file = files.last
    ranks.each do |rank|
      files.each do |file|
        piece = self[ (file + rank).to_sym ]
        #output << file+rank
        output << (piece ? piece.abbrev : ' ')
        output << (file != last_file ? ' ' : "\n")
      end
    end  
    output + "\n"
  end
  
  def allowed_moves
    @allowed_moves ||= self.keys.inject({}) do |moves, position|
      moves[position] = self[position].allowed_moves(self)
      moves
    end
  end
  
  def inspect; "\n" + to_s; end

  # TODO Hash code for board should include everything FENable
end
