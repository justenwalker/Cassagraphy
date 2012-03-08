module TopoSort
  class Vertex
    def initialize(data)
      @visited = false
      @data = data
      @incoming = []
      @outgoing = []
    end
    def inspect
      to_s
    end
    def to_s
      @data
    end
    def visit
      old = @visited
      @visited = true
      return old
    end
    def data
      @data
    end
    def incoming(edge)
      @incoming += [edge]
    end
    def in
      @incoming
    end
    def outgoing(edge)
      @outgoing += [edge]
    end
    def out
      @outgoing
    end
    def remove(edge)
      @outgoing.delete(edge)
      @incoming.delete(edge)
    end
  end

  class Edge
    def initialize(nodea,nodeb)
      @a = nodea
      @b = nodeb
      @a.outgoing(self)
      @b.incoming(self)
    end
    def inspect
      to_s
    end
    def to_s
      "#{@a} --> #{@b}"
    end
    def out
      @b
    end
    def in
      @a
    end
  end

  def self.visit(n,result)
    if( not n.visit() )
      elist = n.in()
      elist.each do |e|
        m = e.in()
        TopoSort::visit(m,result)
      end
      result.push(n)
    end
  end

  def self.sort( nodes )
    result = []
    noOut = []
    nodes.each do |n|
      if n.out().length == 0 # n has no outgoing edges
        noOut += [n]
      end
    end
    # noOut = set of all nodes with no outgoing edges
    noOut.each do |n|
      TopoSort::visit(n,result)
    end
    result
  end
end
