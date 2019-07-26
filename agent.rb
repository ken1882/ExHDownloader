# -*- coding: utf-8 -*-

class Agent < Mechanize

  attr_reader :index
  attr_reader :current_doc
  attr_reader :next_link
  attr_reader :start_index, :dest_index
  attr_reader :progress

  def initialize(index=0)
    @index = index
    super()
  end

  def setup(si=0, di=nil)
    @current_doc = nil
    @next_link   = nil
    @progress    = [0, (di || 0) - si]
    @start_index, @dest_index = si, di
  end
end